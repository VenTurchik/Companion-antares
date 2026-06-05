import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class LocalNetworkDevice {
  String name;
  String platform;
  final String ip;
  DateTime lastSeen;

  LocalNetworkDevice({
    required this.name,
    required this.platform,
    required this.ip,
    required this.lastSeen,
  });
}

class LocalNetworkDiscovery extends ChangeNotifier {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  final List<LocalNetworkDevice> _devices = [];
  final List<Map<String, dynamic>> _servers = [];
  String _myName = '';
  String _myPlatform = '';
  Set<String>? _myIps;

  List<LocalNetworkDevice> get devices => List.unmodifiable(_devices);
  List<Map<String, dynamic>> get servers => List.unmodifiable(_servers);
  bool get isSearching => _isSearching;

  bool _isSearching = false;

  Future<void> start(String name, String platform) async {
    _myName = name;
    _myPlatform = platform;
    await _collectMyIps();
    await _bindSocket();
    _startPeriodicBroadcast();
    _startCleanup();
    _searchServers();
    print('[LAN] Поиск запущен: $_myName ($_myPlatform)');
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  Future<void> _collectMyIps() async {
    try {
      final interfaces = await NetworkInterface.list();
      _myIps = {};
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            if (!ip.startsWith('127.')) {
              _myIps!.add(ip);
            }
          }
        }
      }
    } catch (_) {
      _myIps = {};
    }
  }

  Future<void> _bindSocket() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 9875);
    _socket!.broadcastEnabled = true;
    _socket!.readEventsEnabled = true;
    _socket!.listen(_onPacket);
    print('[LAN] Сокет привязан к порту 9875');
  }

  void _onPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;
    try {
      final msg = utf8.decode(datagram.data);
      final data = jsonDecode(msg);
      if (data is Map<String, dynamic>) {
        if (data['type'] == 'antares_presence') {
          _handleClientPresence(datagram, data);
        } else if (data.containsKey('server_name')) {
          final ip = datagram.address.address;
          final url = data['url'] as String? ?? 'http://$ip:8000';
          _addOrUpdateServer(
            data['server_name']?.toString() ?? 'POLARIS',
            url,
            data['version']?.toString() ?? '',
          );
        }
      }
    } catch (e) {
      print('[LAN] Ошибка обработки пакета: $e');
    }
  }

  void _handleClientPresence(Datagram datagram, Map<String, dynamic> data) {
    final remoteIp = datagram.address.address;
    if (_myIps?.contains(remoteIp) == true) return;

    final name = data['device_name']?.toString() ?? '';
    final platform = data['platform']?.toString() ?? '';
    if (name.isEmpty) return;

    final existing = _devices.indexWhere((d) => d.ip == remoteIp);
    if (existing >= 0) {
      _devices[existing].lastSeen = DateTime.now();
      _devices[existing].name = name;
      _devices[existing].platform = platform;
      print('[LAN] Обновлён анонс клиента: $name ($platform) @ $remoteIp');
    } else {
      _devices.add(LocalNetworkDevice(
        name: name,
        platform: platform,
        ip: remoteIp,
        lastSeen: DateTime.now(),
      ));
      print('[LAN] Найден новый клиент: $name ($platform) @ $remoteIp');
    }
    notifyListeners();
  }

  void _addOrUpdateServer(String name, String url, String version) {
    final existing = _servers.indexWhere((s) => s['url'] == url);
    if (existing >= 0) {
      _servers[existing]['last_seen'] = DateTime.now();
      print('[LAN] Обновлён сервер: $name ($url)');
    } else {
      _servers.add({
        'name': name,
        'url': url,
        'version': version,
        'last_seen': DateTime.now(),
      });
      print('[LAN] Новый сервер: $name ($url)');
    }
    notifyListeners();
  }

  Future<String?> _findLanIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            if (!ip.startsWith('100.') && !ip.startsWith('127.')) {
              return ip;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _searchServers() async {
    _isSearching = true;
    notifyListeners();
    try {
      final localIp = await _findLanIp();
      if (localIp == null) {
        print('[LAN] Не найден IP в локальной сети');
        _isSearching = false;
        notifyListeners();
        return;
      }
      print('[LAN] Использую IP: $localIp');

      final searchSocket = await RawDatagramSocket.bind(InternetAddress(localIp), 0);
      searchSocket.broadcastEnabled = true;

      final serverData = utf8.encode('POLARIS_DISCOVERY');
      final completer = Completer<void>();

      Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) completer.complete();
      });

      searchSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = searchSocket.receive();
          if (datagram != null) {
            try {
              final raw = utf8.decode(datagram.data);
              final data = jsonDecode(raw);
              if (data is Map && data.containsKey('server_name')) {
                final ip = datagram.address.address;
                final url = data['url'] as String? ?? 'http://$ip:8000';
                print('[LAN] Найден сервер: ${data['server_name']} ($url)');
                _addOrUpdateServer(
                  data['server_name']?.toString() ?? 'POLARIS',
                  url,
                  data['version']?.toString() ?? '',
                );
              }
            } catch (e) {
              print('[LAN] Ошибка в ответе сервера: $e');
            }
          }
        }
      });

      for (int port = 9876; port <= 9880; port++) {
        searchSocket.send(serverData, InternetAddress('255.255.255.255'), port);
      }
      print('[LAN] Поиск серверов отправлен на порты 9876-9880 с IP $localIp');
      print('[LAN] Поиск серверов вызван, жду ответы...');

      await completer.future;
      searchSocket.close();
    } catch (e) {
      print('[LAN] Ошибка поиска серверов: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void _startPeriodicBroadcast() {
    _sendPresence();
    _broadcastTimer = Timer.periodic(
        const Duration(seconds: 30), (_) {
      _sendPresence();
      _searchServers();
    });
  }

  void _sendPresence() {
    if (_socket == null) return;
    try {
      final clientPayload = jsonEncode({
        'type': 'antares_presence',
        'device_name': _myName,
        'platform': _myPlatform,
      });
      _socket!.send(
        utf8.encode(clientPayload),
        InternetAddress('255.255.255.255'),
        9875,
      );
      print('[LAN] Анонс клиента отправлен: $_myName ($_myPlatform)');
    } catch (e) {
      print('[LAN] Ошибка отправки: $e');
    }
  }

  void _startCleanup() {
    _cleanupTimer =
        Timer.periodic(const Duration(seconds: 15), (_) {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
      final beforeDevices = _devices.length;
      _devices.removeWhere((d) => d.lastSeen.isBefore(cutoff));
      if (beforeDevices != _devices.length) {
        print('[LAN] Удалено ${beforeDevices - _devices.length} неактивных устройств');
      }

      final serverCutoff = DateTime.now().subtract(const Duration(seconds: 120));
      final beforeServers = _servers.length;
      _servers.removeWhere((s) {
        final lastSeen = s['last_seen'] as DateTime?;
        return lastSeen != null && lastSeen.isBefore(serverCutoff);
      });
      if (beforeServers != _servers.length) {
        print('[LAN] Удалено ${beforeServers - _servers.length} неактивных серверов');
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

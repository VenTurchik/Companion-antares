import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_store.dart';

/// Адаптер для подключения к серверу POLARIS и синхронизации данных.
class AntaresNetworkAdapter extends ChangeNotifier {
  final AppStore _store;

  AntaresNetworkAdapter(this._store);

  HttpClient? _client;
  bool _isConnecting = false;
  Map<String, dynamic>? _serverStats;

  bool get isConnected => _store.isConnected;
  bool get isConnecting => _isConnecting;
  Map<String, dynamic>? get serverStats => _serverStats;

  /// UDP-сканирование сети для поиска POLARIS-серверов.
  static Future<List<Map<String, String>>> discover() async {
    final results = <Map<String, String>>[];

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final data = utf8.encode('POLARIS_DISCOVERY');
      socket.send(data, InternetAddress('255.255.255.255'), 9876);
      socket.send(data, InternetAddress('255.255.255.255'), 9877);
      socket.send(data, InternetAddress('255.255.255.255'), 9878);

      await Future.delayed(const Duration(seconds: 2));

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            try {
              final response = jsonDecode(utf8.decode(datagram.data));
              results.add({
                'name': response['server_name']?.toString() ?? 'POLARIS',
                'url': response['url']?.toString() ?? 'http://${datagram.address.address}:8000',
              });
            } catch (_) {}
          }
        }
      });

      socket.close();
    } catch (_) {}

    return results;
  }

  /// Подключается к POLARIS по URL.
  Future<bool> connect(String url) async {
    final username = _store.userId;
    final authCode = _store.authToken;
    if (username.isEmpty || authCode == null || authCode.isEmpty) return false;

    _isConnecting = true;
    notifyListeners();

    try {
      _client = HttpClient();
      _client!.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse('$url/api/v1/handshake');
      final req = await _client!.postUrl(uri);
      req.headers.contentType = ContentType.json;
      print('=== ДЕБАГ РУКОПОЖАТИЯ ===');
      print('URL: $url/api/v1/handshake');
      print('user_name: $username');
      print('confirmation_code: $authCode');
      print('========================');

      req.write(jsonEncode({
        'client_name': 'Antares',
        'client_version': '0.1.0',
        'user_name': username,
        'confirmation_code': authCode,
      }));

      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final serverName = data['server_name'] as String? ?? 'POLARIS';
        final role = data['user_role'] as String? ?? 'участник';
        await _store.setConnected(url, serverName, role);
        final token = data['session_token'] as String?;
        if (token != null) await _store.setSessionToken(token);
        _isConnecting = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    _client?.close();
    _client = null;
    _isConnecting = false;
    notifyListeners();
    return false;
  }

  /// Отключается от сервера.
  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    await _store.setDisconnected();
    notifyListeners();
  }

  /// Синхронизация канбана.
  Future<Map<String, dynamic>?> syncKanban() => _get('/api/v1/kanban/columns?board_id=1');

  /// Синхронизация заметок.
  Future<Map<String, dynamic>?> syncNotes() => _get('/api/v1/notes');

  /// Синхронизация сниппетов.
  Future<Map<String, dynamic>?> syncSnippets() => _get('/api/v1/snippets');

  /// Получает статистику сервера.
  Future<Map<String, dynamic>?> getServerStats() async {
    final data = await _get('/api/v1/server-stats');
    if (data != null) {
      _serverStats = data;
      notifyListeners();
    }
    return data;
  }

  /// POST запрос.
  Future<bool> post(String path, Map<String, dynamic> data) => _post(path, data);

  /// PUT запрос.
  Future<bool> put(String path, Map<String, dynamic> data) => _put(path, data);

  /// DELETE запрос.
  Future<bool> delete(String path) => _delete(path);

  Future<Map<String, dynamic>?> _get(String path) async {
    if (_client == null || !isConnected) return null;
    try {
      final uri = Uri.parse('${_store.serverUrl}$path');
      final req = await _client!.getUrl(uri);
      _attachAuth(req);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _post(String path, Map<String, dynamic> data) async {
    if (_client == null || !isConnected) return false;
    try {
      final uri = Uri.parse('${_store.serverUrl}$path');
      final req = await _client!.postUrl(uri);
      req.headers.contentType = ContentType.json;
      _attachAuth(req);
      req.write(jsonEncode(data));
      final res = await req.close();
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _put(String path, Map<String, dynamic> data) async {
    if (_client == null || !isConnected) return false;
    try {
      final uri = Uri.parse('${_store.serverUrl}$path');
      final req = await _client!.putUrl(uri);
      req.headers.contentType = ContentType.json;
      _attachAuth(req);
      req.write(jsonEncode(data));
      final res = await req.close();
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _delete(String path) async {
    if (_client == null || !isConnected) return false;
    try {
      final uri = Uri.parse('${_store.serverUrl}$path');
      final req = await _client!.deleteUrl(uri);
      _attachAuth(req);
      final res = await req.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _attachAuth(HttpClientRequest req) {
    if (_store.sessionToken != null) {
      req.headers.set('Authorization', 'Bearer ${_store.sessionToken!}');
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}

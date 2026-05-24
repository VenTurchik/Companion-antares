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
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final data = utf8.encode('POLARIS_DISCOVERY');
      for (int port = 9876; port <= 9880; port++) {
        socket.send(data, InternetAddress('255.255.255.255'), port);
        print('Отправлен запрос на порт $port');
      }

      await Future.delayed(const Duration(seconds: 3));

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket!.receive();
          if (datagram != null) {
            try {
              final response = utf8.decode(datagram.data);
              print('Получен ответ от ${datagram.address.address}:${datagram.port} — $response');
              final json = jsonDecode(response) as Map<String, dynamic>;
              results.add({
                'name': json['server_name'] as String? ?? 'POLARIS',
                'url': json['url'] as String? ?? 'http://${datagram.address.address}:8000',
                'version': json['version'] as String? ?? '',
              });
            } catch (e) {
              print('Ошибка парсинга ответа: $e');
            }
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 500));
      socket.close();
    } catch (e) {
      print('Ошибка сканирования: $e');
    }

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

  /// Экспорт всех данных с сервера одной пачкой.
  Future<Map<String, dynamic>?> syncExport() => _get('/api/v1/export');

  /// Синхронизация канбана.
  Future<Map<String, dynamic>?> syncKanban() => _get('/api/v1/kanban/columns?board_id=1');

  /// Синхронизация заметок.
  Future<List<dynamic>?> syncNotes() => _getList('/api/v1/notes');

  /// Синхронизация сниппетов.
  Future<List<dynamic>?> syncSnippets() => _getList('/api/v1/snippets');

  /// Получает статистику сервера.
  Future<Map<String, dynamic>?> getServerStats() async {
    final data = await _get('/api/v1/server-stats');
    if (data != null) {
      _serverStats = data;
      notifyListeners();
    }
    return data;
  }

  /// Сброс БД сервера (только root).
  Future<bool> resetServerDb() async {
    return (await _post('/api/v1/admin/reset-db', {})) != null;
  }

  /// POST запрос (возвращает true при успехе).
  Future<bool> post(String path, Map<String, dynamic> data) async {
    return (await _post(path, data)) != null;
  }

  /// POST запрос с возвратом тела ответа (для create операций).
  Future<Map<String, dynamic>?> postWithBody(String path, Map<String, dynamic> data) =>
      _post(path, data);

  /// PUT запрос.
  Future<bool> put(String path, Map<String, dynamic> data) => _put(path, data);

  /// DELETE запрос.
  Future<bool> delete(String path) => _delete(path);

  Future<List<dynamic>?> _getList(String path) async {
    if (_client == null || !isConnected) return null;
    try {
      final uri = Uri.parse('${_store.serverUrl}$path');
      final req = await _client!.getUrl(uri);
      _attachAuth(req);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        return jsonDecode(body) as List<dynamic>;
      }
      final body = await res.transform(utf8.decoder).join();
      print('GET $path -> ${res.statusCode}: $body');
    } catch (e) {
      print('GET $path error: $e');
    }
    return null;
  }

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
      final body = await res.transform(utf8.decoder).join();
      print('GET $path -> ${res.statusCode}: $body');
    } catch (e) {
      print('GET $path error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> data) async {
    if (_client == null || !isConnected) return null;
    try {
      final uri = Uri.parse('${_store.serverUrl}$path');
      final req = await _client!.postUrl(uri);
      req.headers.contentType = ContentType.json;
      _attachAuth(req);
      req.write(jsonEncode(data));
      final res = await req.close();
      final ok = res.statusCode == 200 || res.statusCode == 201;
      final body = await res.transform(utf8.decoder).join();
      if (ok) {
        if (body.isEmpty) return {};
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {};
      }
      print('POST $path -> ${res.statusCode}: $body');
      return null;
    } catch (e) {
      print('POST $path error: $e');
      return null;
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
      final ok = res.statusCode == 200 || res.statusCode == 201;
      if (!ok) {
        final body = await res.transform(utf8.decoder).join();
        print('PUT $path -> ${res.statusCode}: $body');
      }
      return ok;
    } catch (e) {
      print('PUT $path error: $e');
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
      final ok = res.statusCode == 200;
      if (!ok) {
        final body = await res.transform(utf8.decoder).join();
        print('DELETE $path -> ${res.statusCode}: $body');
      }
      return ok;
    } catch (e) {
      print('DELETE $path error: $e');
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

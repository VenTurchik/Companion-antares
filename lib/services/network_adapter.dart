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

  bool get isConnected => _store.isConnected;
  bool get isConnecting => _isConnecting;

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

      final uri = Uri.parse('$url/api/auth');
      final req = await _client!.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'username': username,
        'authCode': authCode,
      }));

      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final serverName = data['serverName'] as String? ?? 'POLARIS';
        final role = data['role'] as String? ?? 'участник';
        await _store.setConnected(url, serverName, role);
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
  Future<Map<String, dynamic>?> syncKanban() => _get('/api/kanban');

  /// Синхронизация заметок.
  Future<Map<String, dynamic>?> syncNotes() => _get('/api/notes');

  /// Синхронизация сниппетов.
  Future<Map<String, dynamic>?> syncSnippets() => _get('/api/snippets');

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

  Future<bool> _put(String path, Map<String, dynamic> data) async {
    if (_client == null || !isConnected) return false;
    try {
      final uri = Uri.parse('${_store.serverUrl}$path');
      final req = await _client!.putUrl(uri);
      req.headers.contentType = ContentType.json;
      _attachAuth(req);
      req.write(jsonEncode(data));
      final res = await req.close();
      return res.statusCode == 200;
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
    if (_store.authToken != null) {
      req.headers.set('X-Auth-Code', _store.authToken!);
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}

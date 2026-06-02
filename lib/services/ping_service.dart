import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_store.dart';

/// ChangeNotifier, который раз в 10 секунд пингует сервер и оценивает качество связи.
class PingService extends ChangeNotifier {
  final AppStore _store;

  PingService(this._store);

  int? _currentPing;
  int? get currentPing => _currentPing;

  int? _averagePing;
  int? get averagePing => _averagePing;

  String? _quality;
  String? get quality => _quality;

  final List<int> _history = [];
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
    _check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _currentPing = null;
    _averagePing = null;
    _quality = null;
    _history.clear();
    notifyListeners();
  }

  Future<void> _check() async {
    if (!_store.isConnected || _store.serverUrl == null) return;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse('${_store.serverUrl}/api/v1/ping');
      final start = DateTime.now();
      final req = await client.getUrl(uri);
      final res = await req.close();
      final elapsed = DateTime.now().difference(start).inMilliseconds;

      if (res.statusCode == 200) {
        _currentPing = elapsed;
        _history.add(_currentPing!);
        if (_history.length > 6) _history.removeAt(0);
        _averagePing = _history.reduce((a, b) => a + b) ~/ _history.length;

        if (_currentPing! < 50) {
          _quality = 'отлично';
        } else if (_currentPing! < 100) {
          _quality = 'хорошо';
        } else if (_currentPing! < 200) {
          _quality = 'средне';
        } else {
          _quality = 'плохо';
        }
      } else {
        _currentPing = null;
        _averagePing = null;
        _quality = null;
      }
      client.close();
    } catch (_) {
      _currentPing = null;
      _averagePing = null;
      _quality = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

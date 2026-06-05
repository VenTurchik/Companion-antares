import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../data/repositories/interfaces/work_session_repository.dart';
import '../data/repositories/interfaces/activity_repository.dart';

/// Статус подключения к серверу.
enum ServerConnectionState { local, connected }

/// ChangeNotifier-хранилище пользовательских данных и кеша метрик.
/// Сохраняется в JSON-файл (companion_store.json) для персистентности.
class AppStore extends ChangeNotifier {
  final WorkSessionRepository _workRepo;
  final ActivityRepository _activityRepo;

  AppStore(this._workRepo, this._activityRepo);

  // --- Данные пользователя ---
  String userId = '';
  String? _userName;
  String? authToken;
  final Map<String, String> _serverTokens = {};
  String? localDbPath;
  String? refreshToken;
  String? syncServerUrl;

  String? get userName => _userName;

  // --- Последние серверы ---
  List<Map<String, String>> _recentServers = [];

  List<Map<String, String>> get recentServers =>
      List.unmodifiable(_recentServers);

  void addRecentServer(String url, String name) {
    _recentServers.removeWhere((s) => s['url'] == url);
    _recentServers.insert(0, {
      'url': url,
      'name': name,
      'lastConnected': DateTime.now().toIso8601String(),
    });
    if (_recentServers.length > 5) {
      _recentServers = _recentServers.sublist(0, 5);
    }
    notifyListeners();
  }

  // --- Последний URL сервера (для авто-подключения) ---
  String? _lastServerUrl;

  String? get lastServerUrl => _lastServerUrl;

  Future<void> setLastServerUrl(String url) async {
    _lastServerUrl = url;
    await _persist();
  }

  // --- Идентификатор устройства ---
  String? _deviceId;

  String get deviceId {
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      _persist();
    }
    return _deviceId!;
  }

  Future<void> setDeviceId(String id) async {
    _deviceId = id;
    notifyListeners();
    await _persist();
  }

  // --- Данные подключения к POLARIS ---
  ServerConnectionState _connectionState = ServerConnectionState.local;
  String? _serverUrl;
  String? _serverName;
  String? _userRole; // root | участник
  String? _sessionToken;
  DateTime? _connectedAt;

  ServerConnectionState get connectionState => _connectionState;
  String? get serverUrl => _serverUrl;
  String? get serverName => _serverName;
  String? get userRole => _userRole;
  String? get sessionToken => _sessionToken;
  DateTime? get connectedAt => _connectedAt;
  bool get isConnected => _connectionState == ServerConnectionState.connected;
  String get connectionStatus => isConnected ? 'connected' : 'local';
  bool get isRemote => isConnected;

  String get connectionLabel {
    if (_connectionState == ServerConnectionState.connected && _serverName != null) {
      return 'Подключено: $_serverName';
    }
    return 'Локально';
  }

  static const Map<String, String> roleLabels = {
    'root': 'Владелец',
    'admin': 'Администратор',
    'participant': 'Участник',
    'reader': 'Читатель',
  };

  String get roleLabel {
    if (_userRole == null) return '';
    final label = roleLabels[_userRole] ?? _userRole!;
    return 'Роль: $label';
  }

  // --- Кеш метрик ---
  int todayWorkSeconds = 0;
  Map<String, int> _weeklyWorkCache = {};
  Map<String, int> _dailyActivityCache = {};

  Map<DateTime, int> get weeklyWork {
    final result = <DateTime, int>{};
    for (final e in _weeklyWorkCache.entries) {
      result[DateTime.parse(e.key)] = e.value;
    }
    return result;
  }

  Map<DateTime, int> get dailyActivityCounts {
    final result = <DateTime, int>{};
    for (final e in _dailyActivityCache.entries) {
      result[DateTime.parse(e.key)] = e.value;
    }
    return result;
  }

  bool _loaded = false;
  bool get isReady => _loaded;

  // --- Загрузка из JSON ---
  Future<void> init() async {
    // Сначала загружаем из SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final spAuthToken = prefs.getString('auth_token');
    final spUserName = prefs.getString('user_name');
    final spServerTokens = prefs.getString('server_tokens');

    // Загружаем server_tokens
    if (spServerTokens != null) {
      try {
        final decoded = jsonDecode(spServerTokens) as Map<String, dynamic>;
        _serverTokens.clear();
        decoded.forEach((k, v) => _serverTokens[k] = v.toString());
      } catch (_) {}
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${AppConstants.storeFileName}');
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        userId = data['userId'] as String? ?? '';
        authToken = data['authToken'] as String?;
        refreshToken = data['refreshToken'] as String?;
        syncServerUrl = data['syncServerUrl'] as String?;
        _serverUrl = null;
        _serverName = null;
        _userRole = data['userRole'] as String?;
        _sessionToken = null;
        _deviceId = data['deviceId'] as String?;
        _lastServerUrl = data['lastServerUrl'] as String?;
        if (data['recentServers'] is List) {
          _recentServers = (data['recentServers'] as List).map((e) {
            if (e is Map) return Map<String, String>.from(e);
            return {'url': e.toString(), 'name': e.toString(), 'lastConnected': ''};
          }).toList();
        }
        _connectionState = ServerConnectionState.local;
        _connectedAt = null;
        todayWorkSeconds = data['todayWorkSeconds'] as int? ?? 0;
        if (data['weeklyWork'] != null) {
          _weeklyWorkCache = Map<String, int>.from(data['weeklyWork'] as Map);
        }
        if (data['dailyActivity'] != null) {
          _dailyActivityCache = Map<String, int>.from(data['dailyActivity'] as Map);
        }
        _userName = data['userName'] as String?;
        if (data['lastServerUrl'] != null) {
          _lastServerUrl = data['lastServerUrl'] as String?;
        }
      } catch (_) {}
    }

    // SharedPreferences имеет приоритет (более надёжное хранилище)
    if (spAuthToken != null) authToken = spAuthToken;
    if (spUserName != null) _userName = spUserName;

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${AppConstants.storeFileName}');
    final data = {
      'userId': userId,
      'userName': _userName,
      'authToken': authToken,
      'refreshToken': refreshToken,
      'syncServerUrl': syncServerUrl,
      'recentServers': _recentServers,
      'serverUrl': _serverUrl,
      'serverName': _serverName,
      'userRole': _userRole,
      'sessionToken': _sessionToken,
      'deviceId': _deviceId,
      'lastServerUrl': _lastServerUrl,
      'connectedAt': _connectedAt?.toIso8601String(),
      'todayWorkSeconds': todayWorkSeconds,
      'weeklyWork': _weeklyWorkCache,
      'dailyActivity': _dailyActivityCache,
    };
    await file.writeAsString(jsonEncode(data));
  }

  // --- Сеттеры ---
  Future<void> setAuth(String token, String refresh) async {
    authToken = token;
    refreshToken = refresh;
    notifyListeners();
    await _persist();
  }

  /// Сохраняет код подтверждения в SharedPreferences.
  Future<void> setAuthToken(String token) async {
    authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    notifyListeners();
    await _persist();
  }

  /// Сохраняет код доступа для конкретного сервера.
  Future<void> setServerToken(String url, String token) async {
    _serverTokens[url] = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_tokens', jsonEncode(_serverTokens));
    authToken = token;
    notifyListeners();
    await _persist();
  }

  /// Возвращает код доступа для сервера, если сохранён.
  String? getServerToken(String url) => _serverTokens[url];

  Future<void> setSyncServer(String url) async {
    syncServerUrl = url;
    notifyListeners();
    await _persist();
  }

  /// Сохраняет данные пользователя после онбординга.
  Future<void> setUserData(String name, String code) async {
    userId = name;
    _userName = name;
    authToken = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('auth_token', code);
    notifyListeners();
    await _persist();
  }

  /// Сохраняет только имя пользователя локально.
  Future<void> setUserName(String name) async {
    userId = name;
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    notifyListeners();
    await _persist();
  }

  /// Обновляет статус подключения к POLARIS.
  Future<void> setConnected(String url, String name, String role) async {
    _connectionState = ServerConnectionState.connected;
    _serverUrl = url;
    _serverName = name;
    addRecentServer(url, name);
    _userRole = role;
    _connectedAt = DateTime.now();
    _lastServerUrl = url;
    notifyListeners();
    await _persist();
  }

  /// Сохраняет session_token после рукопожатия.
  Future<void> setSessionToken(String token) async {
    _sessionToken = token;
    notifyListeners();
    await _persist();
  }

  /// Сбрасывает подключение.
  Future<void> setDisconnected() async {
    _connectionState = ServerConnectionState.local;
    _serverUrl = null;
    _serverName = null;
    _userRole = null;
    _sessionToken = null;
    _connectedAt = null;
    notifyListeners();
    await _persist();
  }

  // --- Обновление метрик из БД ---
  Future<void> refreshMetrics() async {
    final today = DateTime.now();

    // Секунды работы сегодня
    final todaySessions = await _workRepo.getTodaySessions();
    int secs = 0;
    for (final s in todaySessions) {
      if (s.endTime != null) secs += s.durationSeconds;
    }
    final active = await _workRepo.getActive();
    if (active != null) {
      secs += DateTime.now().difference(active.startTime).inSeconds;
    }
    todayWorkSeconds = secs;

    // Еженедельная активность (7 дней)
    _weeklyWorkCache = {};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final next = day.add(const Duration(days: 1));
      _weeklyWorkCache[day.toIso8601String()] =
          await _workRepo.getTotalDurationForPeriod(day, next);
    }

    // Ежедневная активность (14 дней)
    _dailyActivityCache = {};
    final activities = await _activityRepo.getAll();
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      _dailyActivityCache[day.toIso8601String()] = 0;
    }
    for (final a in activities) {
      final day = DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
      final key = day.toIso8601String();
      if (_dailyActivityCache.containsKey(key)) {
        _dailyActivityCache[key] = _dailyActivityCache[key]! + 1;
      }
    }

    notifyListeners();
    await _persist();
  }
}

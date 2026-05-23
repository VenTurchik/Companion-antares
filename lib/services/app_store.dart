import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../data/repositories/interfaces/work_session_repository.dart';
import '../data/repositories/interfaces/activity_repository.dart';

/// ChangeNotifier-хранилище пользовательских данных и кеша метрик.
/// Сохраняется в JSON-файл (companion_store.json) для персистентности.
class AppStore extends ChangeNotifier {
  final WorkSessionRepository _workRepo;
  final ActivityRepository _activityRepo;

  AppStore(this._workRepo, this._activityRepo);

  // --- Данные пользователя (для будущей сетевой синхронизации) ---
  String userId = const Uuid().v4();
  String? authToken;
  String? refreshToken;
  DateTime? lastSyncAt;
  String? syncServerUrl;

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
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${AppConstants.storeFileName}');
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        userId = data['userId'] as String? ?? userId;
        authToken = data['authToken'] as String?;
        refreshToken = data['refreshToken'] as String?;
        lastSyncAt = data['lastSyncAt'] != null
            ? DateTime.parse(data['lastSyncAt'] as String)
            : null;
        syncServerUrl = data['syncServerUrl'] as String?;
        todayWorkSeconds = data['todayWorkSeconds'] as int? ?? 0;
        if (data['weeklyWork'] != null) {
          _weeklyWorkCache = Map<String, int>.from(data['weeklyWork'] as Map);
        }
        if (data['dailyActivity'] != null) {
          _dailyActivityCache = Map<String, int>.from(data['dailyActivity'] as Map);
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${AppConstants.storeFileName}');
    final data = {
      'userId': userId,
      'authToken': authToken,
      'refreshToken': refreshToken,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'syncServerUrl': syncServerUrl,
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

  Future<void> setSyncServer(String url) async {
    syncServerUrl = url;
    notifyListeners();
    await _persist();
  }

  Future<void> markSynced() async {
    lastSyncAt = DateTime.now();
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

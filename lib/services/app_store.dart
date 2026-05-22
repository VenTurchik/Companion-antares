import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../repositories/activity_repository.dart';
import '../repositories/work_session_repository.dart';

class AppStore extends ChangeNotifier {
  static const _fileName = 'companion_store.json';

  // --- user data (for future network/sync) ---
  String userId = const Uuid().v4();
  String? authToken;
  String? refreshToken;
  DateTime? lastSyncAt;
  String? syncServerUrl;

  // --- cached metrics ---
  int todayWorkSeconds = 0;
  Map<String, int> _weeklyWorkCache = {};
  Map<String, int> _dailyActivityCache = {};

  Map<DateTime, int> get weeklyWork {
    final result = <DateTime, int>{};
    _weeklyWorkCache.forEach((key, value) {
      result[DateTime.parse(key)] = value;
    });
    return result;
  }

  Map<DateTime, int> get dailyActivityCounts {
    final result = <DateTime, int>{};
    _dailyActivityCache.forEach((key, value) {
      result[DateTime.parse(key)] = value;
    });
    return result;
  }

  bool _loaded = false;
  bool get isReady => _loaded;

  // --- persistence ---
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
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
    final file = File('${dir.path}/$_fileName');
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

  // --- user data setters ---
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

  // --- metrics refresh from DB ---
  Future<void> refreshMetrics() async {
    final activityRepo = ActivityRepository();
    final workRepo = WorkSessionRepository();
    final today = DateTime.now();

    // today work seconds
    final todaySessions = await workRepo.getTodaySessions();
    int secs = 0;
    for (final s in todaySessions) {
      if (s.endTime != null) secs += s.durationSeconds;
    }
    final active = await workRepo.getActive();
    if (active != null) {
      secs += DateTime.now().difference(active.startTime).inSeconds;
    }
    todayWorkSeconds = secs;

    // weekly work
    _weeklyWorkCache = {};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final ds = day.add(const Duration(days: 1));
      final periodSecs = await workRepo.getTotalDurationForPeriod(day, ds);
      _weeklyWorkCache[day.toIso8601String()] = periodSecs;
    }

    // daily activity (14 days)
    _dailyActivityCache = {};
    final activities = await activityRepo.getAll();
    final now = DateTime.now();
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final key = day.toIso8601String();
      _dailyActivityCache[key] = 0;
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

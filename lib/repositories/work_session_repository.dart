import '../database/database_helper.dart';
import '../models/work_session.dart';
import '../models/activity.dart';

class WorkSessionRepository {
  final db = DatabaseHelper();

  Future<WorkSession?> getActive() async {
    final maps = await db.db.query(
      'work_sessions',
      where: 'endTime IS NULL',
      orderBy: 'startTime DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WorkSession.fromMap(maps.first);
  }

  Future<List<WorkSession>> getTodaySessions() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final maps = await db.db.query(
      'work_sessions',
      where: 'startTime >= ? AND startTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'startTime ASC',
    );
    return maps.map((m) => WorkSession.fromMap(m)).toList();
  }

  Future<int> getTotalDurationForPeriod(
      DateTime start, DateTime end) async {
    final maps = await db.db.query(
      'work_sessions',
      where: 'startTime >= ? AND startTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    int total = 0;
    for (final m in maps) {
      final s = WorkSession.fromMap(m);
      if (s.endTime != null) total += s.durationSeconds;
    }
    return total;
  }

  Future<WorkSession> start({String? taskId}) async {
    final session = WorkSession(startTime: DateTime.now(), taskId: taskId);
    await db.db.insert('work_sessions', session.toMap());
    await db.insertActivity(Activity(type: ActivityType.timerStarted));
    return session;
  }

  Future<void> stop(WorkSession session) async {
    session.endTime = DateTime.now();
    session.durationSeconds =
        session.endTime!.difference(session.startTime).inSeconds;
    await db.db.update(
      'work_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
    await db.insertActivity(Activity(type: ActivityType.timerStopped));
  }

  Future<void> insertManual(WorkSession session) async {
    await db.db.insert('work_sessions', session.toMap());
  }
}

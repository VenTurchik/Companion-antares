import 'package:sqflite/sqflite.dart';
import '../../../models/work_session.dart';

/// Операции с таблицей work_sessions.
class WorkSessionsTable {
  final Database db;
  WorkSessionsTable(this.db);

  Future<WorkSession?> getActive() async {
    final maps = await db.query(
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
    final maps = await db.query(
      'work_sessions',
      where: 'startTime >= ? AND startTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'startTime ASC',
    );
    return maps.map((m) => WorkSession.fromMap(m)).toList();
  }

  Future<int> getTotalDurationForPeriod(DateTime start, DateTime end) async {
    final maps = await db.query(
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

  Future<void> insert(WorkSession session) async =>
      db.insert('work_sessions', session.toMap());

  Future<void> update(WorkSession session) async =>
      db.update('work_sessions', session.toMap(),
          where: 'id = ?', whereArgs: [session.id]);
}

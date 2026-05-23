import 'package:sqflite/sqflite.dart';
import '../../../models/activity.dart';

/// Операции с таблицей activities.
class ActivitiesTable {
  final Database db;
  ActivitiesTable(this.db);

  Future<List<Activity>> getAll() async {
    final maps = await db.query('activities', orderBy: 'timestamp DESC');
    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  Future<List<Activity>> getBetween(DateTime start, DateTime end) async {
    final maps = await db.query(
      'activities',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  Future<void> insert(Activity activity) async =>
      db.insert('activities', activity.toMap());
}

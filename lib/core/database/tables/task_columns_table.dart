import 'package:sqflite/sqflite.dart';
import '../../../models/task_column.dart';

/// Операции с таблицей task_columns.
class TaskColumnsTable {
  final Database db;
  TaskColumnsTable(this.db);

  Future<List<TaskColumn>> getAll() async {
    final maps = await db.query('task_columns', orderBy: 'sortOrder ASC');
    return maps.map((m) => TaskColumn.fromMap(m)).toList();
  }

  Future<TaskColumn?> getById(String id) async {
    final maps = await db.query('task_columns', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return TaskColumn.fromMap(maps.first);
  }

  Future<void> insert(TaskColumn col) async =>
      db.insert('task_columns', col.toMap());

  Future<void> update(TaskColumn col) async =>
      db.update('task_columns', col.toMap(), where: 'id = ?', whereArgs: [col.id]);

  Future<void> delete(String id) async =>
      db.delete('task_columns', where: 'id = ?', whereArgs: [id]);
}

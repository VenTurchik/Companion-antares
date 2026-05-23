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

  Future<void> insert(TaskColumn col) async =>
      db.insert('task_columns', col.toMap());

  Future<void> delete(String id) async =>
      db.delete('task_columns', where: 'id = ?', whereArgs: [id]);
}

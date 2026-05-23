import 'package:sqflite/sqflite.dart';
import '../../../models/task.dart';

/// Операции с таблицей tasks.
class TasksTable {
  final Database db;
  TasksTable(this.db);

  Future<List<Task>> getAll() async {
    final maps = await db.query('tasks', orderBy: 'updatedAt DESC');
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<Task?> getById(String id) async {
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<void> insert(Task task) async => db.insert('tasks', task.toMap());

  Future<void> update(Task task) async {
    task.updatedAt = DateTime.now();
    db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> delete(String id) async =>
      db.delete('tasks', where: 'id = ?', whereArgs: [id]);

  /// Генерирует следующий номер в формате TASK-XXXX.
  Future<String> nextTaskNumber() async {
    final maps = await db.query('tasks');
    int max = 0;
    for (final m in maps) {
      final num = int.tryParse(
          (m['taskNumber'] as String).replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null && num > max) max = num;
    }
    return 'TASK-${(max + 1).toString().padLeft(4, '0')}';
  }
}

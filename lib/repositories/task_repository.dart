import '../database/database_helper.dart';
import '../models/task.dart';
import '../models/activity.dart';

class TaskRepository {
  final db = DatabaseHelper();

  Future<List<Task>> getAll() => db.getTasks();

  Future<void> create(Task task) async {
    final maxNumber = await _nextTaskNumber();
    task.taskNumber = maxNumber;
    await db.insertTask(task);
    await db.insertActivity(Activity(type: ActivityType.taskCreated));
  }

  Future<void> update(Task task) async {
    if (task.status == 'done' && task.completedAt == null) {
      task.completedAt = DateTime.now();
      await db.insertActivity(Activity(type: ActivityType.taskCompleted));
    }
    if (task.status != 'done') {
      task.completedAt = null;
    }
    task.updatedAt = DateTime.now();
    await db.updateTask(task);
  }

  Future<void> delete(String id) => db.deleteTask(id);

  Future<String> _nextTaskNumber() async {
    final tasks = await getAll();
    int max = 0;
    for (final t in tasks) {
      final num =
          int.tryParse(t.taskNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null && num > max) max = num;
    }
    return 'TASK-${(max + 1).toString().padLeft(4, '0')}';
  }
}

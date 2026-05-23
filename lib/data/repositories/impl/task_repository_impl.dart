import '../../../core/database/database_helper.dart';
import '../../../models/task.dart';
import '../../../models/activity.dart';
import '../interfaces/task_repository.dart';

/// Реализация репозитория задач через DatabaseHelper (SQLite).
class TaskRepositoryImpl implements TaskRepository {
  final DatabaseHelper _db;

  TaskRepositoryImpl(this._db);

  @override
  Future<List<Task>> getAll() => _db.tasks.getAll();

  @override
  Future<Task?> getById(String id) => _db.tasks.getById(id);

  @override
  Future<void> create(Task task) async {
    task.taskNumber = await _db.tasks.nextTaskNumber();
    await _db.tasks.insert(task);
    await _db.activities.insert(Activity(type: ActivityType.taskCreated));
  }

  @override
  Future<void> update(Task task) async {
    if (task.status == 'done' && task.completedAt == null) {
      task.completedAt = DateTime.now();
      await _db.activities.insert(Activity(type: ActivityType.taskCompleted));
    }
    if (task.status != 'done') {
      task.completedAt = null;
    }
    await _db.tasks.update(task);
  }

  @override
  Future<void> delete(String id) => _db.tasks.delete(id);
}

import '../../../core/database/database_helper.dart';
import '../../../models/task.dart';
import '../../../models/activity.dart';
import '../interfaces/task_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';
import '../../../services/app_store.dart';

class TaskRepositoryImpl implements TaskRepository {
  final DatabaseHelper _db;
  final AppStore _store;
  final TaskRemoteSource _remote;

  TaskRepositoryImpl(this._db, this._store, AntaresNetworkAdapter adapter)
      : _remote = TaskRemoteSource(adapter);

  bool get _useRemote => _store.isRemote;

  @override
  Future<List<Task>> getAll() async {
    if (_useRemote) {
      final remote = await _remote.getAll();
      return remote ?? [];
    }
    return _db.tasks.getAll();
  }

  @override
  Future<Task?> getById(String id) async {
    if (_useRemote) {
      final tasks = await _remote.getAll();
      if (tasks != null) {
        try {
          return tasks.firstWhere((t) => t.id == id);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    return _db.tasks.getById(id);
  }

  @override
  Future<void> create(Task task) async {
    if (_useRemote) {
      await _remote.create(task);
      return;
    }
    task.taskNumber = await _db.tasks.nextTaskNumber();
    await _db.tasks.insert(task);
    await _db.activities.insert(Activity(type: ActivityType.taskCreated));
  }

  @override
  Future<void> update(Task task) async {
    if (_useRemote) {
      await _remote.update(task);
      return;
    }
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
  Future<void> delete(String id) async {
    if (_useRemote) {
      await _remote.delete(id);
      return;
    }
    await _db.tasks.delete(id);
  }
}

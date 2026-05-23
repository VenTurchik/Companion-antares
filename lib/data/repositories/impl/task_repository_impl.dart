import '../../../core/database/database_helper.dart';
import '../../../models/task.dart';
import '../../../models/activity.dart';
import '../interfaces/task_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';

/// Реализация репозитория задач через DatabaseHelper (SQLite) или удалённо.
class TaskRepositoryImpl implements TaskRepository {
  final DatabaseHelper _db;
  final AntaresNetworkAdapter? _adapter;
  final bool _useRemote;
  TaskRemoteSource? _remote;

  TaskRepositoryImpl(this._db, {AntaresNetworkAdapter? adapter, bool useRemote = false})
      : _adapter = adapter,
        _useRemote = useRemote {
    if (adapter != null) _remote = TaskRemoteSource(adapter);
  }

  bool get _shouldUseRemote {
    final a = _adapter;
    return _useRemote && a != null && a.isConnected;
  }

  @override
  Future<List<Task>> getAll() async {
    if (_shouldUseRemote) {
      final remote = await _remote!.getAll();
      if (remote != null) return remote;
    }
    return _db.tasks.getAll();
  }

  @override
  Future<Task?> getById(String id) => _db.tasks.getById(id);

  @override
  Future<void> create(Task task) async {
    task.taskNumber = await _db.tasks.nextTaskNumber();
    await _db.tasks.insert(task);
    await _db.activities.insert(Activity(type: ActivityType.taskCreated));
    if (_shouldUseRemote) {
      await _remote!.create(task);
    }
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
    if (_shouldUseRemote) {
      await _remote!.update(task);
    }
  }

  @override
  Future<void> delete(String id) async {
    await _db.tasks.delete(id);
    if (_shouldUseRemote) {
      await _remote!.delete(id);
    }
  }
}

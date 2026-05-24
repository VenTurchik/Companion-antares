import 'package:uuid/uuid.dart';
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
      if (remote == null) return [];
      final mappings = await _db.idMappings.getAllMappings('task');
      final result = <Task>[];
      for (final t in remote) {
        final localId = mappings[t.id];
        if (localId != null) {
          result.add(Task(
            id: localId,
            taskNumber: t.taskNumber,
            title: t.title,
            description: t.description,
            status: t.status,
            commitHash: t.commitHash,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            completedAt: t.completedAt,
          ));
        } else {
          final newId = const Uuid().v4();
          await _db.idMappings.save(newId, t.id, 'task');
          result.add(Task(
            id: newId,
            taskNumber: t.taskNumber,
            title: t.title,
            description: t.description,
            status: t.status,
            commitHash: t.commitHash,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            completedAt: t.completedAt,
          ));
        }
      }
      return result;
    }
    return _db.tasks.getAll();
  }

  @override
  Future<Task?> getById(String id) async {
    if (_useRemote) {
      final tasks = await getAll();
      try {
        return tasks.firstWhere((t) => t.id == id);
      } catch (_) {
        return null;
      }
    }
    return _db.tasks.getById(id);
  }

  @override
  Future<void> create(Task task) async {
    if (_useRemote) {
      final response = await _remote.create(task.toCreateMap(1));
      final remoteId = response?['id']?.toString();
      if (remoteId != null) {
        await _db.idMappings.save(task.id, remoteId, 'task');
      }
      return;
    }
    task.taskNumber = await _db.tasks.nextTaskNumber();
    await _db.tasks.insert(task);
    await _db.activities.insert(Activity(type: ActivityType.taskCreated));
  }

  @override
  Future<void> update(Task task) async {
    if (_useRemote) {
      final remoteId = await _db.idMappings.getRemoteId('task', task.id);
      if (remoteId != null) {
        await _remote.update(remoteId, task.toUpdateMap());
      }
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
  Future<void> move(String id, String newStatus) async {
    if (_useRemote) {
      final remoteId = await _db.idMappings.getRemoteId('task', id);
      if (remoteId != null) {
        await _remote.move(remoteId, newStatus);
      }
      return;
    }
    final task = await _db.tasks.getById(id);
    if (task != null) {
      task.status = newStatus;
      await _db.tasks.update(task);
    }
  }

  @override
  Future<void> delete(String id) async {
    if (_useRemote) {
      final remoteId = await _db.idMappings.getRemoteId('task', id);
      if (remoteId != null) {
        await _remote.delete(remoteId);
        await _db.idMappings.deleteByLocalId('task', id);
      }
      return;
    }
    await _db.tasks.delete(id);
  }
}

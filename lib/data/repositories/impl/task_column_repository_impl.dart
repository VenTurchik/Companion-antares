import '../../../core/database/database_helper.dart';
import '../../../models/task_column.dart';
import '../interfaces/task_column_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';
import '../../../services/app_store.dart';

class TaskColumnRepositoryImpl implements TaskColumnRepository {
  final DatabaseHelper _db;
  final AppStore _store;
  final TaskColumnRemoteSource _remote;

  TaskColumnRepositoryImpl(this._db, this._store, AntaresNetworkAdapter adapter)
      : _remote = TaskColumnRemoteSource(adapter);

  bool get _useRemote => _store.isRemote;

  @override
  Future<List<TaskColumn>> getAll() async {
    if (_useRemote) {
      final remote = await _remote.getAll();
      return remote ?? [];
    }
    return _db.taskColumns.getAll();
  }

  @override
  Future<void> insert(TaskColumn column) async {
    if (_useRemote) {
      await _remote.createColumn({
        'name': column.name,
        'statusKey': column.statusKey,
        'colorValue': column.colorValue,
      });
      return;
    }
    await _db.taskColumns.insert(column);
  }

  @override
  Future<void> delete(TaskColumn column) async {
    if (_useRemote) {
      await _remote.deleteColumn(column.statusKey);
      return;
    }
    await _db.taskColumns.delete(column.id);
  }

  @override
  Future<void> update(TaskColumn column) async {
    if (_useRemote) {
      await _remote.updateColumn(column.statusKey, {
        'name': column.name,
        'colorValue': column.colorValue,
      });
      return;
    }
    await _db.taskColumns.update(column);
  }
}

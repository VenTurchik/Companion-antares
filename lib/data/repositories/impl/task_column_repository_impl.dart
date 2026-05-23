import '../../../core/database/database_helper.dart';
import '../../../models/task_column.dart';
import '../interfaces/task_column_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';

class TaskColumnRepositoryImpl implements TaskColumnRepository {
  final DatabaseHelper _db;
  final AntaresNetworkAdapter? _adapter;
  final bool _useRemote;
  TaskColumnRemoteSource? _remote;

  TaskColumnRepositoryImpl(this._db, {AntaresNetworkAdapter? adapter, bool useRemote = false})
      : _adapter = adapter,
        _useRemote = useRemote {
    if (adapter != null) _remote = TaskColumnRemoteSource(adapter);
  }

  bool get _shouldUseRemote {
    final a = _adapter;
    return _useRemote && a != null && a.isConnected;
  }

  @override
  Future<List<TaskColumn>> getAll() async {
    if (_shouldUseRemote) {
      final remote = await _remote!.getAll();
      if (remote != null) return remote;
    }
    return _db.taskColumns.getAll();
  }

  @override
  Future<void> insert(TaskColumn column) => _db.taskColumns.insert(column);

  @override
  Future<void> delete(String id) => _db.taskColumns.delete(id);
}

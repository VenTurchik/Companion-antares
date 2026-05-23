import '../../../core/database/database_helper.dart';
import '../../../models/task_column.dart';
import '../interfaces/task_column_repository.dart';

class TaskColumnRepositoryImpl implements TaskColumnRepository {
  final DatabaseHelper _db;
  TaskColumnRepositoryImpl(this._db);

  @override
  Future<List<TaskColumn>> getAll() => _db.taskColumns.getAll();

  @override
  Future<void> insert(TaskColumn column) => _db.taskColumns.insert(column);

  @override
  Future<void> delete(String id) => _db.taskColumns.delete(id);
}

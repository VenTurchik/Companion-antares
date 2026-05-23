import '../../../models/task_column.dart';

abstract class TaskColumnRepository {
  Future<List<TaskColumn>> getAll();
  Future<void> insert(TaskColumn column);
  Future<void> delete(String id);
}

import '../../../models/task.dart';

/// Абстракция репозитория задач (DIP: зависит от абстракции, не от конкретной БД).
abstract class TaskRepository {
  Future<List<Task>> getAll();
  Future<Task?> getById(String id);
  Future<void> create(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);
}

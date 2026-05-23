/// Ключи статусов задач (соответствуют TaskColumn.statusKey).
class TaskStatusKeys {
  TaskStatusKeys._();
  static const todo = 'todo';
  static const inProgress = 'inProgress';
  static const done = 'done';
}

/// Константы приложения.
class AppConstants {
  AppConstants._();
  static const appName = 'Companion';
  static const dbName = 'companion.db';
  static const storeFileName = 'companion_store.json';
  static const taskNumberPrefix = 'TASK-';
  static const defaultLanguage = 'dart';
  static const defaultUsername = 'Разработчик';
  static const defaultIdeCommand = 'code';
  static const artifactRetentionDays = 7;
}

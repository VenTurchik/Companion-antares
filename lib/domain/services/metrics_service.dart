import '../../models/activity.dart';
import '../../models/work_session.dart';
import '../../data/repositories/interfaces/activity_repository.dart';
import '../../data/repositories/interfaces/work_session_repository.dart';
import '../../data/repositories/interfaces/task_repository.dart';
import '../../core/constants.dart';

/// Сервис для расчёта метрик производительности.
/// Инкапсулирует логику агрегации данных из нескольких репозиториев.
class MetricsService {
  final ActivityRepository _activityRepo;
  final WorkSessionRepository _workRepo;
  final TaskRepository _taskRepo;

  MetricsService(this._activityRepo, this._workRepo, this._taskRepo);

  /// Количество секунд работы сегодня (включая активную сессию).
  Future<int> getTodayWorkSeconds() async {
    final sessions = await _workRepo.getTodaySessions();
    int secs = 0;
    for (final s in sessions) {
      if (s.endTime != null) secs += s.durationSeconds;
    }
    final active = await _workRepo.getActive();
    if (active != null) {
      secs += DateTime.now().difference(active.startTime).inSeconds;
    }
    return secs;
  }

  /// Ежедневная активность за последние 14 дней.
  Future<Map<DateTime, int>> getDailyActivityCounts() async {
    final activities = await _activityRepo.getAll();
    final now = DateTime.now();
    final map = <DateTime, int>{};
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      map[day] = 0;
    }
    for (final a in activities) {
      final day = DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
      if (map.containsKey(day)) map[day] = map[day]! + 1;
    }
    return map;
  }

  /// Секунд работы за каждый из последних 7 дней.
  Future<Map<DateTime, int>> getWeeklyWorkSeconds() async {
    final now = DateTime.now();
    final map = <DateTime, int>{};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final next = day.add(const Duration(days: 1));
      map[day] = await _workRepo.getTotalDurationForPeriod(day, next);
    }
    return map;
  }

  /// Активность за определённый период.
  Future<List<Activity>> getActivitiesBetween(DateTime start, DateTime end) =>
      _activityRepo.getBetween(start, end);

  /// Количество активностей по типу.
  Future<Map<ActivityType, int>> getActivityTypeCounts() async {
    final activities = await _activityRepo.getAll();
    final map = <ActivityType, int>{};
    for (final a in activities) {
      map[a.type] = (map[a.type] ?? 0) + 1;
    }
    return map;
  }

  /// Статистика по задачам: всего, в работе, выполнено.
  Future<Map<String, int>> getTaskStats() async {
    final tasks = await _taskRepo.getAll();
    return {
      'total': tasks.length,
      TaskStatusKeys.inProgress: tasks.where((t) => t.status == TaskStatusKeys.inProgress).length,
      'done': tasks.where((t) => t.status == TaskStatusKeys.done).length,
    };
  }

  /// Добавляет ручную запись о рабочей сессии.
  Future<void> addManualTime(WorkSession session) async {
    await _workRepo.insertManual(session);
  }

  /// Завершено задач сегодня.
  Future<int> getTaskCompletedToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final activities = await _activityRepo.getBetween(start, end);
    return activities.where((a) => a.type == ActivityType.taskCompleted).length;
  }
}

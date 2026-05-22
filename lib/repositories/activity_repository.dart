import '../database/database_helper.dart';
import '../models/activity.dart';

class ActivityRepository {
  final db = DatabaseHelper();

  Future<List<Activity>> getAll() => db.getActivities();

  Future<List<Activity>> getBetween(DateTime start, DateTime end) =>
      db.getActivitiesBetween(start, end);
}

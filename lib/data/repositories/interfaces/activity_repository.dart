import '../../../models/activity.dart';

abstract class ActivityRepository {
  Future<List<Activity>> getAll();
  Future<List<Activity>> getBetween(DateTime start, DateTime end);
}

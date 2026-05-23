import '../../../core/database/database_helper.dart';
import '../../../models/activity.dart';
import '../interfaces/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final DatabaseHelper _db;
  ActivityRepositoryImpl(this._db);

  @override
  Future<List<Activity>> getAll() => _db.activities.getAll();

  @override
  Future<List<Activity>> getBetween(DateTime start, DateTime end) =>
      _db.activities.getBetween(start, end);
}

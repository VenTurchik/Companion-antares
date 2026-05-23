import '../../../core/database/database_helper.dart';
import '../../../models/work_session.dart';
import '../../../models/activity.dart';
import '../interfaces/work_session_repository.dart';

class WorkSessionRepositoryImpl implements WorkSessionRepository {
  final DatabaseHelper _db;
  WorkSessionRepositoryImpl(this._db);

  @override
  Future<WorkSession?> getActive() => _db.workSessions.getActive();

  @override
  Future<List<WorkSession>> getTodaySessions() =>
      _db.workSessions.getTodaySessions();

  @override
  Future<int> getTotalDurationForPeriod(DateTime start, DateTime end) =>
      _db.workSessions.getTotalDurationForPeriod(start, end);

  @override
  Future<WorkSession> start({String? taskId}) async {
    final session = WorkSession(startTime: DateTime.now(), taskId: taskId);
    await _db.workSessions.insert(session);
    await _db.activities.insert(Activity(type: ActivityType.timerStarted));
    return session;
  }

  @override
  Future<void> stop(WorkSession session) async {
    session.endTime = DateTime.now();
    session.durationSeconds =
        session.endTime!.difference(session.startTime).inSeconds;
    await _db.workSessions.update(session);
    await _db.activities.insert(Activity(type: ActivityType.timerStopped));
  }

  @override
  Future<void> insertManual(WorkSession session) async {
    await _db.workSessions.insert(session);
  }
}

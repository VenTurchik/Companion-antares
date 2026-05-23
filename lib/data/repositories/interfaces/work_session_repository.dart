import '../../../models/work_session.dart';

abstract class WorkSessionRepository {
  Future<WorkSession?> getActive();
  Future<List<WorkSession>> getTodaySessions();
  Future<int> getTotalDurationForPeriod(DateTime start, DateTime end);
  Future<WorkSession> start({String? taskId});
  Future<void> stop(WorkSession session);
  Future<void> insertManual(WorkSession session);
}

import 'package:uuid/uuid.dart';

class WorkSession {
  final String id;
  DateTime startTime;
  DateTime? endTime;
  int durationSeconds;
  String? taskId;

  WorkSession({
    String? id,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.taskId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'taskId': taskId,
  };

  factory WorkSession.fromMap(Map<String, dynamic> map) => WorkSession(
    id: map['id'] as String,
    startTime: DateTime.parse(map['startTime'] as String),
    endTime: map['endTime'] != null
        ? DateTime.parse(map['endTime'] as String)
        : null,
    durationSeconds: map['durationSeconds'] as int? ?? 0,
    taskId: map['taskId'] as String?,
  );
}

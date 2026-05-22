import 'package:uuid/uuid.dart';

enum ActivityType {
  taskCreated,
  taskCompleted,
  noteCreated,
  snippetCreated,
  timerStarted,
  timerStopped,
}

class Activity {
  final String id;
  ActivityType type;
  DateTime timestamp;

  Activity({
    String? id,
    required this.type,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
    id: map['id'] as String,
    type: ActivityType.values.firstWhere(
      (e) => e.name == map['type'],
    ),
    timestamp: DateTime.parse(map['timestamp'] as String),
  );
}

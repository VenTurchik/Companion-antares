import 'package:uuid/uuid.dart';

class Task {
  final String id;
  String taskNumber;
  String title;
  String? description;
  String status;
  String? commitHash;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;

  Task({
    String? id,
    String? taskNumber,
    required this.title,
    this.description,
    this.status = 'todo',
    this.commitHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        taskNumber = taskNumber ?? 'TASK-0000',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'taskNumber': taskNumber,
    'title': title,
    'description': description,
    'status': status,
    'commitHash': commitHash,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as String,
    taskNumber: map['taskNumber'] as String? ?? 'TASK-0000',
    title: map['title'] as String,
    description: map['description'] as String?,
    status: map['status'] as String? ?? 'todo',
    commitHash: map['commitHash'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    completedAt: map['completedAt'] != null
        ? DateTime.parse(map['completedAt'] as String)
        : null,
  );
}

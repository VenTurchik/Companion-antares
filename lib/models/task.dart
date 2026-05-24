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
    id: map['id']?.toString() ?? const Uuid().v4(),
    taskNumber: map['taskNumber']?.toString() ?? 'TASK-0000',
    title: map['title']?.toString() ?? '',
    description: map['description']?.toString(),
    status: map['status']?.toString() ?? 'todo',
    commitHash: map['commitHash']?.toString(),
    createdAt: map['createdAt'] != null
        ? DateTime.parse(map['createdAt'] as String)
        : DateTime.now(),
    updatedAt: map['updatedAt'] != null
        ? DateTime.parse(map['updatedAt'] as String)
        : DateTime.now(),
    completedAt: map['completedAt'] != null
        ? DateTime.tryParse(map['completedAt'] as String)
        : null,
  );
}

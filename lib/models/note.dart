import 'package:uuid/uuid.dart';

class Note {
  final String id;
  String title;
  String content;
  String? taskId;
  DateTime createdAt;
  DateTime updatedAt;

  Note({
    String? id,
    required this.title,
    required this.content,
    this.taskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'taskId': taskId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as String,
    title: map['title'] as String,
    content: map['content'] as String,
    taskId: map['taskId'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}

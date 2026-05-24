import 'dart:convert';
import 'package:uuid/uuid.dart';

class Snippet {
  final String id;
  String title;
  String code;
  String language;
  List<String> tags;
  String? noteId;
  DateTime createdAt;

  Snippet({
    String? id,
    required this.title,
    required this.code,
    required this.language,
    List<String>? tags,
    this.noteId,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'code': code,
    'language': language,
    'tags': jsonEncode(tags),
    'noteId': noteId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Snippet.fromMap(Map<String, dynamic> map) => Snippet(
    id: map['id']?.toString() ?? const Uuid().v4(),
    title: map['title']?.toString() ?? '',
    code: map['code']?.toString() ?? '',
    language: map['language']?.toString() ?? '',
    tags: map['tags'] != null
        ? (jsonDecode(map['tags'] as String) as List).cast<String>()
        : [],
    noteId: map['noteId']?.toString(),
    createdAt: map['createdAt'] != null
        ? DateTime.parse(map['createdAt'] as String)
        : DateTime.now(),
  );
}

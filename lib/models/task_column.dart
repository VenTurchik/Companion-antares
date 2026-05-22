import 'package:uuid/uuid.dart';

class TaskColumn {
  final String id;
  String name;
  String statusKey;
  int colorValue;
  int sortOrder;
  bool isDefault;

  TaskColumn({
    String? id,
    required this.name,
    required this.statusKey,
    this.colorValue = 0xFF9E9E9E,
    this.sortOrder = 0,
    this.isDefault = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'statusKey': statusKey,
    'colorValue': colorValue,
    'sortOrder': sortOrder,
    'isDefault': isDefault ? 1 : 0,
  };

  factory TaskColumn.fromMap(Map<String, dynamic> map) => TaskColumn(
    id: map['id'] as String,
    name: map['name'] as String,
    statusKey: map['statusKey'] as String,
    colorValue: map['colorValue'] as int? ?? 0xFF9E9E9E,
    sortOrder: map['sortOrder'] as int? ?? 0,
    isDefault: (map['isDefault'] as int? ?? 0) == 1,
  );

  static List<TaskColumn> defaults() => [
    TaskColumn(
      name: 'To Do',
      statusKey: 'todo',
      colorValue: 0xFF9E9E9E,
      sortOrder: 0,
      isDefault: true,
    ),
    TaskColumn(
      name: 'In Progress',
      statusKey: 'inProgress',
      colorValue: 0xFF2196F3,
      sortOrder: 1,
      isDefault: true,
    ),
    TaskColumn(
      name: 'Done',
      statusKey: 'done',
      colorValue: 0xFF4CAF50,
      sortOrder: 2,
      isDefault: true,
    ),
  ];
}

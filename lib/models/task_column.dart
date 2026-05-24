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
    id: map['id']?.toString() ?? const Uuid().v4(),
    name: map['name']?.toString() ?? '',
    statusKey: map['statusKey']?.toString() ?? '',
    colorValue: map['colorValue'] as int? ?? 0xFF9E9E9E,
    sortOrder: map['sortOrder'] as int? ?? 0,
    isDefault: (map['isDefault'] as int? ?? 0) == 1,
  );
}

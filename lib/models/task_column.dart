import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TaskColumn {
  final String id;
  String name;
  String statusKey;
  String colorValue;
  int sortOrder;
  bool isDefault;

  TaskColumn({
    String? id,
    required this.name,
    required this.statusKey,
    this.colorValue = '#808080',
    this.sortOrder = 0,
    this.isDefault = false,
  }) : id = id ?? const Uuid().v4();

  Color get color {
    final h = colorValue.replaceFirst('#', '');
    return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'statusKey': statusKey,
    'colorValue': colorValue,
    'sortOrder': sortOrder,
    'isDefault': isDefault ? 1 : 0,
  };

  factory TaskColumn.fromMap(Map<String, dynamic> json) {
    String colorStr;
    final colorVal = json['colorValue'];
    if (colorVal is String && colorVal.startsWith('#')) {
      colorStr = colorVal;
    } else if (colorVal is String && colorVal.startsWith('0x')) {
      colorStr = '#${colorVal.substring(2)}';
    } else if (colorVal is int) {
      colorStr = '#${colorVal.toRadixString(16).padLeft(8, '0').substring(2)}';
    } else {
      colorStr = '#808080';
    }

    return TaskColumn(
      id: json['id']?.toString() ?? json['statusKey']?.toString() ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      statusKey: json['statusKey'] as String? ?? json['id']?.toString() ?? '',
      colorValue: colorStr,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? '0') ?? 0,
      isDefault: json['isDefault'] == true || json['isDefault'] == 1,
    );
  }
}

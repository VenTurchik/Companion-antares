import 'package:flutter/material.dart';
import '../../../models/task_column.dart';
import '../../../models/task.dart';
import '../../../core/constants.dart';

/// Диалог создания/редактирования задачи.
Future<Map<String, String?>?> showTaskDialog(
  BuildContext context, {
  Task? task,
  List<TaskColumn> columns = const [],
}) {
  final titleCtrl = TextEditingController(text: task?.title ?? '');
  final descCtrl = TextEditingController(text: task?.description ?? '');
  final hashCtrl = TextEditingController(text: task?.commitHash ?? '');
  String selectedStatus = TaskStatusKeys.todo;

  return showDialog<Map<String, String?>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(task == null ? 'Новая задача' : 'Редактировать'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Заголовок'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
            TextField(
              controller: hashCtrl,
              decoration: const InputDecoration(labelText: 'Commit hash'),
            ),
            if (columns.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: 'Колонка'),
                items: columns.map((c) => DropdownMenuItem(
                  value: c.statusKey,
                  child: Row(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Color(c.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ],
                  ),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedStatus = v);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'title': titleCtrl.text,
              'description': descCtrl.text.isEmpty ? null : descCtrl.text,
              'commitHash': hashCtrl.text.isEmpty ? null : hashCtrl.text,
            }),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}

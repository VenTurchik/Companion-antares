import 'package:flutter/material.dart';
import '../../../models/task_column.dart';
import '../../../models/task.dart';

/// Диалог создания/редактирования задачи.
Future<Map<String, String?>?> showTaskDialog(
  BuildContext context, {
  Task? task,
  List<TaskColumn> columns = const [],
}) {
  final titleCtrl = TextEditingController(text: task?.title ?? '');
  final descCtrl = TextEditingController(text: task?.description ?? '');
  final hashCtrl = TextEditingController(text: task?.commitHash ?? '');
  final uniqueColumns = <String, TaskColumn>{};
  for (final col in columns) {
    uniqueColumns[col.statusKey] = col;
  }
  final statuses = uniqueColumns.keys.toList();
  String selectedStatus = task?.status ?? statuses.first;
  if (!statuses.contains(selectedStatus)) selectedStatus = statuses.first;

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
                items: statuses.map((status) {
                  final col = uniqueColumns[status]!;
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: col.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(col.name),
                      ],
                    ),
                  );
                }).toList(),
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
              'statusKey': selectedStatus,
            }),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}

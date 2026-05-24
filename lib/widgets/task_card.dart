import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onArchive;
  final int noteCount;
  final int snippetCount;

  const TaskCard({
    super.key,
    required this.task,
    this.statusColor = Colors.grey,
    required this.onTap,
    required this.onDelete,
    this.onArchive,
    this.noteCount = 0,
    this.snippetCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 60,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.taskNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (task.description != null &&
                            task.description!.isNotEmpty)
                          const Icon(Icons.description_outlined, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Создано: ${dateFormat.format(task.createdAt)}',
                        style: theme.textTheme.bodySmall),
                    if (task.updatedAt
                            .difference(task.createdAt)
                            .inSeconds >
                        1)
                      Text('Изменено: ${dateFormat.format(task.updatedAt)}',
                          style: theme.textTheme.bodySmall),
                    if (task.status == 'done' && task.completedAt != null)
                      Text('Завершено: ${dateFormat.format(task.completedAt!)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.green)),
                    if (noteCount > 0 || snippetCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (noteCount > 0)
                              _chip(Icons.description, '$noteCount', theme),
                            if (snippetCount > 0)
                              _chip(Icons.code, '$snippetCount', theme),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (task.status != 'done' && onArchive != null)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.check_circle_outline,
                            size: 18, color: Colors.green),
                        onPressed: onArchive,
                        tooltip: 'Завершить',
                      ),
                    ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

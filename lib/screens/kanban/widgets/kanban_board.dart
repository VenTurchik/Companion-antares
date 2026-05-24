import 'package:flutter/material.dart';
import '../../../models/task.dart';
import '../../../models/task_column.dart';
import '../../../widgets/kanban_column.dart';

const defaultStatusKeys = {'todo', 'in_progress', 'done'};

/// Виджет доски канбана: рендерит колонки из TaskColumn, каждая показывает
/// задачи с соответствующим statusKey.
class KanbanBoard extends StatelessWidget {
  final List<TaskColumn> columns;
  final List<Task> tasks;
  final Map<String, int> noteCounts;
  final Map<String, int> snippetCounts;
  final void Function(Task task) onTap;
  final void Function(Task task) onDelete;
  final void Function(Task task)? onArchive;
  final Future<void> Function(Task task, String newStatusKey) onMoveTask;
  final Future<void> Function(TaskColumn col) onDeleteColumn;
  final void Function(TaskColumn col)? onEditColumn;

  const KanbanBoard({
    super.key,
    required this.columns,
    required this.tasks,
    required this.noteCounts,
    required this.snippetCounts,
    required this.onTap,
    required this.onDelete,
    this.onArchive,
    required this.onMoveTask,
    required this.onDeleteColumn,
    this.onEditColumn,
  });

  @override
  Widget build(BuildContext context) {
    final boardCols = columns.where((c) => c.statusKey != 'done').toList();
    if (boardCols.isEmpty) {
      return const Center(child: Text('Нет колонок. Добавьте новую колонку.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: boardCols.map((col) {
          final colTasks = tasks.where((t) => t.status == col.statusKey).toList();
          return SizedBox(
            width: 280,
            child: KanbanColumn(
              title: col.name,
              color: col.color,
              tasks: colTasks,
              onTap: onTap,
              onDelete: onDelete,
              onArchive: onArchive,
              onAccept: (t) => onMoveTask(t, col.statusKey),
              noteCounts: noteCounts,
              snippetCounts: snippetCounts,
              headerTrailing: defaultStatusKeys.contains(col.statusKey)
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onEditColumn != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            onPressed: () => onEditColumn!(col),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => onDeleteColumn(col),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

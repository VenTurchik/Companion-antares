import 'package:flutter/material.dart';
import '../../../models/task.dart';
import '../../../models/task_column.dart';

/// Вкладка "Таблица": список активных (не done) задач в виде Card-списка.
class KanbanTableTab extends StatelessWidget {
  final List<Task> tasks;
  final List<TaskColumn> columns;
  final void Function(Task task) onTap;

  const KanbanTableTab({
    super.key,
    required this.tasks,
    required this.columns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('Нет задач'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final col = columns.where((c) => c.statusKey == task.status).firstOrNull;
        return Card(
          child: ListTile(
            leading: Container(
              width: 4, height: 32,
              decoration: BoxDecoration(
                color: col != null ? col.color : Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text('${task.taskNumber} ${task.title}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(col?.name ?? task.status),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => onTap(task),
          ),
        );
      },
    );
  }
}

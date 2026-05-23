import 'package:flutter/material.dart';
import '../../../models/task.dart';

/// Вкладка "Архив": завершённые задачи (status == done).
class ArchiveTab extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task task) onTap;
  final void Function(Task task) onUnarchive;
  final void Function(Task task) onDelete;

  const ArchiveTab({
    super.key,
    required this.tasks,
    required this.onTap,
    required this.onUnarchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('Архив пуст'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.archive, color: Colors.grey),
            title: Text('${task.taskNumber} ${task.title}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: const Text('Завершена'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.unarchive, size: 18),
                  tooltip: 'Вернуть на доску',
                  onPressed: () => onUnarchive(task),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => onDelete(task),
                ),
              ],
            ),
            onTap: () => onTap(task),
          ),
        );
      },
    );
  }
}

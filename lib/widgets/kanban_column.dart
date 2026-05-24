import 'package:flutter/material.dart';
import '../models/task.dart';
import 'task_card.dart';

class KanbanColumn extends StatelessWidget {
  final String title;
  final Color color;
  final List<Task> tasks;
  final void Function(Task task) onTap;
  final void Function(Task task) onDelete;
  final void Function(Task task)? onArchive;
  final void Function(Task task) onAccept;
  final Map<String, int> noteCounts;
  final Map<String, int> snippetCounts;
  final Widget? headerTrailing;

  const KanbanColumn({
    super.key,
    required this.title,
    required this.color,
    required this.tasks,
    required this.onTap,
    required this.onDelete,
    this.onArchive,
    required this.onAccept,
    this.noteCounts = const {},
    this.snippetCounts = const {},
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isHovering
                ? color.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: isHovering ? Border.all(color: color, width: 2) : null,
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$title (${tasks.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    ?headerTrailing,
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 220,
                          child: TaskCard(
                            task: task,
                            onTap: () {},
                            onDelete: () {},
                            onArchive: onArchive != null ? () => onArchive!(task) : null,
                            noteCount: noteCounts[task.id] ?? 0,
                            snippetCount: snippetCounts[task.id] ?? 0,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: TaskCard(
                          task: task,
                          onTap: () {},
                          onDelete: () {},
                          onArchive: onArchive != null ? () => onArchive!(task) : null,
                          noteCount: noteCounts[task.id] ?? 0,
                          snippetCount: snippetCounts[task.id] ?? 0,
                        ),
                      ),
                      child: TaskCard(
                        task: task,
                        onTap: () => onTap(task),
                        onDelete: () => onDelete(task),
                        onArchive: onArchive != null ? () => onArchive!(task) : null,
                        noteCount: noteCounts[task.id] ?? 0,
                        snippetCount: snippetCounts[task.id] ?? 0,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

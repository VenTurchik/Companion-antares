import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/task_column.dart';
import '../../models/note.dart';
import '../../models/snippet.dart';
import '../../domain/services/task_service.dart';
import '../../services/work_timer_service.dart';
import '../../core/constants.dart';
import '../../core/errors/app_exception.dart';
import '../../services/app_store.dart';
import '../tasks/task_detail_screen.dart';
import 'dialogs/task_dialog.dart';
import 'dialogs/column_dialog.dart';
import 'widgets/kanban_board.dart';
import 'widgets/kanban_table_tab.dart';
import 'widgets/archive_tab.dart';
import '../../widgets/ping_indicator.dart';
import '../../widgets/role_badge.dart';

/// Экран канбан-доски с тремя вкладками: Доска, Таблица, Архив.
class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  List<Task> _tasks = [];
  List<TaskColumn> _columns = [];
  List<Note> _notes = [];
  List<Snippet> _snippets = [];
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final taskService = context.read<TaskService>();
    final tasks = await taskService.getAllTasks();
    final columns = await taskService.getColumns();
    final notes = await taskService.getAllNotes();
    final snippets = await taskService.getAllSnippets();
    setState(() {
      _tasks = tasks;
      _columns = columns;
      _notes = notes;
      _snippets = snippets;
    });
  }

  List<Task> _boardTasks() =>
      _tasks.where((t) => t.status != TaskStatusKeys.done).toList();

  List<Task> _archiveTasks() =>
      _tasks.where((t) => t.status == TaskStatusKeys.done).toList();

  Map<String, int> _noteCounts() {
    final map = <String, int>{};
    for (final n in _notes) {
      if (n.taskId != null) map[n.taskId!] = (map[n.taskId!] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> _snippetCounts() {
    final noteIds = _notes.where((n) => n.taskId != null).map((n) => n.id).toSet();
    final map = <String, int>{};
    for (final s in _snippets) {
      if (s.noteId != null && noteIds.contains(s.noteId)) {
        final note = _notes.firstWhere((n) => n.id == s.noteId);
        if (note.taskId != null) map[note.taskId!] = (map[note.taskId!] ?? 0) + 1;
      }
    }
    return map;
  }

  Future<void> _moveTask(Task task, String newStatusKey) async {
    try {
      final timer = context.read<WorkTimerService>();
      await context.read<TaskService>().moveTask(
        task, newStatusKey,
        timerRunning: timer.isRunning,
      );
      _load();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _delete(Task task) async {
    await context.read<TaskService>().deleteTask(task.id);
    _load();
  }

  Future<void> _showDetail(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
    );
    _load();
  }

  Future<void> _create() async {
    final result = await showTaskDialog(context, columns: _columns);
    if (result != null) {
      await context.read<TaskService>().createTask(Task(
        title: result['title']!,
        description: result['description'],
        commitHash: result['commitHash'],
        status: result['statusKey'] ?? 'todo',
      ));
      _load();
    }
  }

  Future<void> _addColumn() async {
    final result = await showColumnDialog(context);
    if (result != null) {
      await context.read<TaskService>().addColumn(TaskColumn(
        name: result['name']!,
        statusKey: result['statusKey']!,
        colorValue: result['colorValue']!,
        sortOrder: _columns.length,
      ));
      _load();
    }
  }

  Future<void> _deleteColumn(TaskColumn col) async {
    const defaultKeys = {'todo', 'in_progress', 'done'};
    if (col.isDefault || defaultKeys.contains(col.statusKey)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя удалить стандартную колонку')),
        );
      }
      return;
    }
    try {
      await context.read<TaskService>().deleteColumn(col);
      _load();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _editColumn(TaskColumn col) async {
    final result = await showEditColumnDialog(context, column: col);
    if (result != null) {
      col.name = result['name']!;
      col.colorValue = result['colorValue']!;
      await context.read<TaskService>().updateColumn(col);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final noteCounts = _noteCounts();
    final snippetCounts = _snippetCounts();
    final canCreate = store.userRole != 'reader';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Канбан'),
        actions: [
          const RoleBadge(),
          const PingIndicator(),
          if (_tabIndex == 0 && canCreate)
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Добавить колонку',
              onPressed: _addColumn,
            ),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add_task),
              tooltip: 'Новая задача',
              onPressed: _create,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _tabButton(theme, 'Доска', 0),
                const SizedBox(width: 8),
                _tabButton(theme, 'Таблица', 1),
                const SizedBox(width: 8),
                _tabButton(theme, 'Архив (${_archiveTasks().length})', 2),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildTabContent(noteCounts, snippetCounts, canDelete: store.userRole == 'admin' || store.userRole == 'root')),
        ],
      ),
    );
  }

  Widget _tabButton(ThemeData theme, String label, int index) {
    final selected = _tabIndex == index;
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: selected ? theme.colorScheme.primaryContainer : null,
        foregroundColor: selected ? theme.colorScheme.onPrimaryContainer : null,
      ),
      onPressed: () => setState(() => _tabIndex = index),
      child: Text(label),
    );
  }

  Widget _buildTabContent(Map<String, int> noteCounts, Map<String, int> snippetCounts, {bool canDelete = true}) {
    switch (_tabIndex) {
      case 0: return KanbanBoard(
        columns: _columns,
        tasks: _tasks,
        noteCounts: noteCounts,
        snippetCounts: snippetCounts,
        onTap: _showDetail,
        onDelete: canDelete ? _delete : (_) {},
        onArchive: (t) => _moveTask(t, 'done'),
        onMoveTask: _moveTask,
        onDeleteColumn: canDelete ? _deleteColumn : (_) async {},
        onEditColumn: _editColumn,
      );
      case 1: return KanbanTableTab(
        tasks: _boardTasks(),
        columns: _columns,
        onTap: _showDetail,
      );
      case 2: return ArchiveTab(
        tasks: _archiveTasks(),
        onTap: _showDetail,
        onUnarchive: (t) => _moveTask(t, TaskStatusKeys.todo),
        onDelete: canDelete ? _delete : (_) {},
      );
      default: return const SizedBox();
    }
  }
}

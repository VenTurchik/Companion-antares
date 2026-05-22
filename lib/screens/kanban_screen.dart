import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/task_column.dart';
import '../models/note.dart';
import '../models/snippet.dart';
import '../database/database_helper.dart';
import '../repositories/task_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/snippet_repository.dart';
import '../services/work_timer_service.dart';
import '../widgets/kanban_column.dart';
import 'task_detail_screen.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  final _repo = TaskRepository();
  final _noteRepo = NoteRepository();
  final _snippetRepo = SnippetRepository();
  final _db = DatabaseHelper();
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
    final tasks = await _repo.getAll();
    final columns = await _db.getTaskColumns();
    final notes = await _noteRepo.getAll();
    final snippets = await _snippetRepo.getAll();
    setState(() {
      _tasks = tasks;
      _columns = columns;
      _notes = notes;
      _snippets = snippets;
    });
  }

  List<Task> _byStatus(String statusKey) =>
      _tasks.where((t) => t.status == statusKey).toList();

  List<Task> _boardTasks() =>
      _tasks.where((t) => t.status != 'done').toList();

  List<Task> _archiveTasks() =>
      _tasks.where((t) => t.status == 'done').toList();

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
    if (newStatusKey == 'inProgress') {
      final timer = context.read<WorkTimerService>();
      if (!timer.isRunning) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сначала запустите рабочий таймер'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
    task.status = newStatusKey;
    await _repo.update(task);
    _load();
  }

  Future<void> _delete(Task task) async {
    await _repo.delete(task.id);
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
    final result = await _showTaskDialog(context, columns: _columns);
    if (result != null) {
      await _repo.create(Task(
        title: result['title']!,
        description: result['description'],
        commitHash: result['commitHash'],
      ));
      _load();
    }
  }

  Future<void> _addColumn() async {
    final result = await _showColumnDialog(context);
    if (result != null) {
      await _db.insertTaskColumn(TaskColumn(
        name: result['name']!,
        statusKey: result['statusKey']!,
        colorValue: result['colorValue']!,
        sortOrder: _columns.length,
      ));
      _load();
    }
  }

  Future<void> _deleteColumn(TaskColumn col) async {
    if (col.isDefault) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя удалить стандартную колонку')),
        );
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить колонку?'),
        content: Text('Задачи в колонке "${col.name}" будут удалены'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final t in _byStatus(col.statusKey)) {
        await _repo.delete(t.id);
      }
      await _db.deleteTaskColumn(col.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteCounts = _noteCounts();
    final snippetCounts = _snippetCounts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Канбан'),
        actions: [
          if (_tabIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Добавить колонку',
              onPressed: _addColumn,
            ),
          ],
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
          Expanded(child: _buildTabContent(noteCounts, snippetCounts)),
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

  Widget _buildTabContent(Map<String, int> noteCounts, Map<String, int> snippetCounts) {
    switch (_tabIndex) {
      case 0:
        return _buildBoard(noteCounts, snippetCounts);
      case 1:
        return _buildTable();
      case 2:
        return _buildArchive();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBoard(Map<String, int> noteCounts, Map<String, int> snippetCounts) {
    final boardCols = _columns.where((c) => c.statusKey != 'done').toList();
    if (boardCols.isEmpty) {
      return const Center(child: Text('Нет колонок. Добавьте новую колонку.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: boardCols.map((col) {
          return SizedBox(
            width: 280,
            child: KanbanColumn(
              title: col.name,
              color: Color(col.colorValue),
              tasks: _byStatus(col.statusKey),
              onTap: _showDetail,
              onDelete: _delete,
              onAccept: (t) => _moveTask(t, col.statusKey),
              noteCounts: noteCounts,
              snippetCounts: snippetCounts,
              headerTrailing: col.isDefault
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: () => _deleteColumn(col),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTable() {
    final boardTasks = _boardTasks();
    if (boardTasks.isEmpty) {
      return const Center(child: Text('Нет задач'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: boardTasks.length,
      itemBuilder: (context, index) {
        final task = boardTasks[index];
        final col = _columns.where((c) => c.statusKey == task.status).firstOrNull;
        return Card(
          child: ListTile(
            leading: Container(
              width: 4, height: 32,
              decoration: BoxDecoration(
                color: col != null ? Color(col.colorValue) : Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text('${task.taskNumber} ${task.title}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(col?.name ?? task.status),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => _showDetail(task),
          ),
        );
      },
    );
  }

  Widget _buildArchive() {
    final archived = _archiveTasks();
    if (archived.isEmpty) {
      return const Center(child: Text('Архив пуст'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: archived.length,
      itemBuilder: (context, index) {
        final task = archived[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.archive, color: Colors.grey),
            title: Text('${task.taskNumber} ${task.title}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('Завершена'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.unarchive, size: 18),
                  tooltip: 'Вернуть на доску',
                  onPressed: () => _moveTask(task, 'todo'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _delete(task),
                ),
              ],
            ),
            onTap: () => _showDetail(task),
          ),
        );
      },
    );
  }
}

Future<Map<String, String?>?> _showTaskDialog(
  BuildContext context, {
  Task? task,
  List<TaskColumn> columns = const [],
}) {
  final titleCtrl = TextEditingController(text: task?.title ?? '');
  final descCtrl = TextEditingController(text: task?.description ?? '');
  final hashCtrl = TextEditingController(text: task?.commitHash ?? '');
  String selectedStatus = 'todo';

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

Future<Map<String, dynamic>?> _showColumnDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final keyCtrl = TextEditingController();
  Color pickedColor = Colors.blue;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Новая колонка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Ключ статуса',
                helperText: 'напр. reviewing, blocked',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Цвет: '),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final color = await showDialog<Color>(
                      context: ctx,
                      builder: (c) => SimpleDialog(
                        title: const Text('Выберите цвет'),
                        children: [
                          Colors.blue, Colors.green, Colors.orange, Colors.red,
                          Colors.purple, Colors.teal, Colors.brown, Colors.indigo,
                        ].map((clr) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(c, clr),
                          child: Row(
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: clr,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(_colorName(clr)),
                            ],
                          ),
                        )).toList(),
                      ),
                    );
                    if (color != null) setDialogState(() => pickedColor = color);
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: pickedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || keyCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameCtrl.text.trim(),
                'statusKey': keyCtrl.text.trim(),
                'colorValue': pickedColor.toARGB32(),
              });
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    ),
  );
}

String _colorName(Color c) {
  if (c == Colors.blue) return 'Синий';
  if (c == Colors.green) return 'Зелёный';
  if (c == Colors.orange) return 'Оранжевый';
  if (c == Colors.red) return 'Красный';
  if (c == Colors.purple) return 'Фиолетовый';
  if (c == Colors.teal) return 'Бирюзовый';
  if (c == Colors.brown) return 'Коричневый';
  if (c == Colors.indigo) return 'Индиго';
  return 'Другой';
}

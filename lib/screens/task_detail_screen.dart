import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
import 'note_editor_screen.dart';
import 'snippet_editor_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _taskRepo = TaskRepository();
  final _noteRepo = NoteRepository();
  final _snippetRepo = SnippetRepository();

  late Task _task;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  List<Note> _linkedNotes = [];
  List<Snippet> _linkedSnippets = [];
  List<Note> _allNotes = [];
  List<Snippet> _allSnippets = [];
  bool _editing = false;
  List<TaskColumn> _columns = [];
  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _titleCtrl = TextEditingController(text: _task.title);
    _descCtrl = TextEditingController(text: _task.description ?? '');
    _loadColumns();
    _loadLinked();
  }

  Future<void> _loadColumns() async {
    final cols = await DatabaseHelper().getTaskColumns();
    setState(() => _columns = cols);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLinked() async {
    final notes = await _noteRepo.getAll();
    final snippets = await _snippetRepo.getAll();
    setState(() {
      _allNotes = notes;
      _allSnippets = snippets;
      _linkedNotes = notes.where((n) => n.taskId == _task.id).toList();
      final linkedIds = _linkedNotes.map((n) => n.id).toSet();
      _linkedSnippets = snippets
          .where(
              (s) => s.noteId != null && linkedIds.contains(s.noteId))
          .toList();
    });
  }

  Future<void> _save() async {
    _task.title = _titleCtrl.text;
    _task.description =
        _descCtrl.text.isEmpty ? null : _descCtrl.text;
    await _taskRepo.update(_task);
    setState(() => _editing = false);
  }

  Future<void> _changeStatus(String statusKey) async {
    if (statusKey == 'inProgress') {
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
    _task.status = statusKey;
    await _taskRepo.update(_task);
    _loadLinked();
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _taskRepo.delete(_task.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_task.taskNumber),
        actions: [
          if (_editing)
            IconButton(
                icon: const Icon(Icons.save), onPressed: _save)
          else
            IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _editing = true)),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteTask),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: _task.taskNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Скопировано: TASK-XXXX')),
              );
            },
            child: Text(_task.taskNumber,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.indigo)),
          ),
          const SizedBox(height: 8),
          _editing
              ? TextField(
                  controller: _titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Заголовок'),
                  style: theme.textTheme.headlineSmall)
              : Text(_task.title,
                  style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _columns.any((c) => c.statusKey == _task.status)
                ? _task.status
                : null,
            decoration:
                const InputDecoration(labelText: 'Статус'),
            items: _columns.map((c) => DropdownMenuItem(
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
                ))).toList(),
            onChanged: (v) {
              if (v != null) _changeStatus(v);
            },
          ),
          const SizedBox(height: 12),
          Text('Описание', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          _editing
              ? TextField(
                  controller: _descCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder()))
              : Text(_task.description ?? '—',
                  style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _meta('Создано',
                      _dateFormat.format(_task.createdAt), theme),
                  _meta('Изменено',
                      _dateFormat.format(_task.updatedAt), theme),
                  if (_task.completedAt != null)
                    _meta('Завершено',
                        _dateFormat.format(_task.completedAt!),
                        theme, Colors.green),
                  if (_task.commitHash != null)
                    _meta('Commit', _task.commitHash!, theme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Заметки (${_linkedNotes.length})',
                  style: theme.textTheme.titleSmall),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Привязать'),
                onPressed: _attachNote,
              ),
            ],
          ),
          ..._linkedNotes.map((n) => ListTile(
            dense: true,
            title: Text(n.title),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => NoteEditorScreen(note: n))),
          )),
          if (_linkedNotes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text('Нет связанных заметок'),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Сниппеты (${_linkedSnippets.length})',
                  style: theme.textTheme.titleSmall),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Привязать'),
                onPressed: _attachSnippet,
              ),
            ],
          ),
          ..._linkedSnippets.map((s) => ListTile(
            dense: true,
            title: Text(s.title),
            subtitle: Text(s.language),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SnippetEditorScreen(snippet: s))),
          )),
          if (_linkedSnippets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text('Нет связанных сниппетов'),
            ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value, ThemeData theme,
      [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  Future<void> _attachNote() async {
    final available = _allNotes
        .where((n) => n.taskId == null || n.taskId == _task.id)
        .toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет доступных заметок')));
      }
      return;
    }
    final note = await showDialog<Note>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Выберите заметку'),
        children: available
            .map((n) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, n),
                  child: Text(n.title,
                      overflow: TextOverflow.ellipsis),
                ))
            .toList(),
      ),
    );
    if (note != null) {
      note.taskId = _task.id;
      await _noteRepo.update(note);
      _loadLinked();
    }
  }

  Future<void> _attachSnippet() async {
    if (_linkedNotes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Сначала привяжите заметку к задаче')));
      }
      return;
    }
    final linkedIds = _linkedNotes.map((n) => n.id).toSet();
    final available = _allSnippets
        .where((s) =>
            s.noteId == null || linkedIds.contains(s.noteId))
        .toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет доступных сниппетов')));
      }
      return;
    }
    final snippet = await showDialog<Snippet>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Выберите сниппет'),
        children: available
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Text(s.title,
                      overflow: TextOverflow.ellipsis),
                ))
            .toList(),
      ),
    );
    if (snippet != null) {
      snippet.noteId = _linkedNotes.first.id;
      await _snippetRepo.update(snippet);
      _loadLinked();
    }
  }
}

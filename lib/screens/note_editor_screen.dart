import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../repositories/note_repository.dart';
import '../repositories/task_repository.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _repo = NoteRepository();
  final _taskRepo = TaskRepository();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _preview = false;
  List<Task> _tasks = [];
  String? _taskId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
    _taskId = widget.note?.taskId;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await _taskRepo.getAll();
    setState(() => _tasks = tasks);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final note = widget.note ?? Note(title: '', content: '');
    note.title = _titleCtrl.text;
    note.content = _contentCtrl.text;
    note.taskId = _taskId;
    if (widget.note == null) {
      await _repo.create(note);
    } else {
      await _repo.update(note);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Новая заметка' : 'Редактировать'),
        actions: [
          IconButton(
            icon: Icon(_preview ? Icons.edit : Icons.visibility),
            onPressed: () => setState(() => _preview = !_preview),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Заголовок'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: _taskId,
              decoration: const InputDecoration(
                  labelText: 'Привязать к задаче'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Без задачи')),
                ..._tasks.map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(t.title,
                        overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _taskId = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _preview
                  ? Markdown(data: _contentCtrl.text)
                  : TextField(
                      controller: _contentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Markdown',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      expands: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

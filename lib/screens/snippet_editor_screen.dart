import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/darcula.dart';
// ignore: unused_import — регистрирует языки для подсветки
import 'package:highlight/languages/all.dart';
import 'package:provider/provider.dart';

import '../models/snippet.dart';
import '../models/note.dart';
import '../repositories/snippet_repository.dart';
import '../repositories/note_repository.dart';
import '../services/settings_service.dart';

class SnippetEditorScreen extends StatefulWidget {
  final Snippet? snippet;
  const SnippetEditorScreen({super.key, this.snippet});

  @override
  State<SnippetEditorScreen> createState() => _SnippetEditorScreenState();
}

class _SnippetEditorScreenState extends State<SnippetEditorScreen> {
  final _repo = SnippetRepository();
  final _noteRepo = NoteRepository();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _codeCtrl;
  late String _language;
  late final TextEditingController _tagsCtrl;
  bool _preview = false;
  List<Note> _notes = [];
  String? _noteId;

  final _languages = [
    'dart', 'python', 'javascript', 'typescript', 'java', 'kotlin',
    'swift', 'go', 'rust', 'cpp', 'c', 'yaml', 'json', 'xml', 'sql',
    'shell', 'css', 'html',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.snippet?.title ?? '');
    _codeCtrl = TextEditingController(text: widget.snippet?.code ?? '');
    _language = widget.snippet?.language ??
        context.read<SettingsService>().defaultLanguage;
    _tagsCtrl = TextEditingController(
        text: widget.snippet?.tags.join(', ') ?? '');
    _noteId = widget.snippet?.noteId;
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _noteRepo.getAll();
    setState(() => _notes = notes);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) {
      return;
    }
    final snippet = widget.snippet ??
        Snippet(title: '', code: '', language: _language);
    snippet.title = _titleCtrl.text;
    snippet.code = _codeCtrl.text;
    snippet.language = _language;
    snippet.tags = _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    snippet.noteId = _noteId;
    if (widget.snippet == null) {
      await _repo.create(snippet);
    } else {
      await _repo.update(snippet);
    }
    if (mounted) Navigator.pop(context);
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _codeCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Скопировано'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.snippet == null ? 'Новый сниппет' : 'Редактировать'),
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
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Язык'),
              items: _languages
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsCtrl,
              decoration:
                  const InputDecoration(labelText: 'Теги (через запятую)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: _noteId,
              decoration: const InputDecoration(
                  labelText: 'Привязать к заметке'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Без заметки')),
                ..._notes.map((n) => DropdownMenuItem(
                    value: n.id,
                    child: Text(n.title,
                        overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _noteId = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _preview
                  ? Stack(
                      children: [
                        HighlightView(
                          _codeCtrl.text,
                          language: _language,
                          theme: darculaTheme,
                          padding: const EdgeInsets.all(12),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: _copy,
                          ),
                        ),
                      ],
                    )
                  : TextField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Код',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

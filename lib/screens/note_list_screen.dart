import 'package:flutter/material.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import 'note_editor_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final _repo = NoteRepository();
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await _repo.getAll();
    setState(() => _notes = notes);
  }

  Future<void> _open(Note? note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
    _load();
  }

  Future<void> _delete(Note note) async {
    await _repo.delete(note.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заметки')),
      body: ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              title: Text(note.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _delete(note),
              ),
              onTap: () => _open(note),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

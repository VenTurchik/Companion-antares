import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../domain/services/task_service.dart';
import '../../widgets/ping_indicator.dart';
import '../../widgets/role_badge.dart';
import '../../services/app_store.dart';
import 'note_editor_screen.dart';

/// Экран списка заметок.
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<Note> _notes = [];
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _load();
    }
  }

  Future<void> _load() async {
    final notes = await context.read<TaskService>().getAllNotes();
    setState(() => _notes = notes);
  }

  Future<void> _delete(Note note) async {
    await context.read<TaskService>().deleteNote(note.id);
    _load();
  }

  Future<void> _open(Note? note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => NoteEditorScreen(note: note)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canCreate = store.userRole != 'reader';
    final canDelete = store.userRole == 'root';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        actions: [
          const RoleBadge(),
          const PingIndicator(),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _open(null),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _notes.isEmpty
            ? const Center(child: Text('Нет заметок'))
            : ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  return ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      note.content.replaceAll(RegExp(r'\s+'), ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: canDelete
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(note),
                          )
                        : null,
                    onTap: () => _open(note),
                  );
                },
              ),
      ),
    );
  }
}

import '../database/database_helper.dart';
import '../models/note.dart';
import '../models/activity.dart';

class NoteRepository {
  final db = DatabaseHelper();

  Future<List<Note>> getAll() => db.getNotes();

  Future<void> create(Note note) async {
    await db.insertNote(note);
    await db.insertActivity(Activity(type: ActivityType.noteCreated));
  }

  Future<void> update(Note note) => db.updateNote(note);

  Future<void> delete(String id) => db.deleteNote(id);
}

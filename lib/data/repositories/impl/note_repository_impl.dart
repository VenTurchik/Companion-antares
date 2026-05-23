import '../../../core/database/database_helper.dart';
import '../../../models/note.dart';
import '../../../models/activity.dart';
import '../interfaces/note_repository.dart';

class NoteRepositoryImpl implements NoteRepository {
  final DatabaseHelper _db;
  NoteRepositoryImpl(this._db);

  @override
  Future<List<Note>> getAll() => _db.notes.getAll();

  @override
  Future<void> create(Note note) async {
    await _db.notes.insert(note);
    await _db.activities.insert(Activity(type: ActivityType.noteCreated));
  }

  @override
  Future<void> update(Note note) => _db.notes.update(note);

  @override
  Future<void> delete(String id) => _db.notes.delete(id);
}

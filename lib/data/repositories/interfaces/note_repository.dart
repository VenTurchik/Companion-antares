import '../../../models/note.dart';

abstract class NoteRepository {
  Future<List<Note>> getAll();
  Future<void> create(Note note);
  Future<void> update(Note note);
  Future<void> delete(String id);
}

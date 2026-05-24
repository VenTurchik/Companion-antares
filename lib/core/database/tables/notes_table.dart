import 'package:sqflite/sqflite.dart';
import '../../../models/note.dart';

/// Операции с таблицей notes.
class NotesTable {
  final Database db;
  NotesTable(this.db);

  Future<List<Note>> getAll() async {
    final maps = await db.query('notes', orderBy: 'updatedAt DESC');
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<Note?> getById(String id) async {
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<void> insert(Note note) async => db.insert('notes', note.toMap());

  Future<void> update(Note note) async {
    note.updatedAt = DateTime.now();
    db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> delete(String id) async =>
      db.delete('notes', where: 'id = ?', whereArgs: [id]);
}

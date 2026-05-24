import 'package:sqflite/sqflite.dart';
import '../../../models/snippet.dart';

/// Операции с таблицей snippets.
class SnippetsTable {
  final Database db;
  SnippetsTable(this.db);

  Future<List<Snippet>> getAll() async {
    final maps = await db.query('snippets', orderBy: 'createdAt DESC');
    return maps.map((m) => Snippet.fromMap(m)).toList();
  }

  Future<Snippet?> getById(String id) async {
    final maps = await db.query('snippets', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Snippet.fromMap(maps.first);
  }

  Future<void> insert(Snippet snippet) async =>
      db.insert('snippets', snippet.toMap());

  Future<void> update(Snippet snippet) async =>
      db.update('snippets', snippet.toMap(),
          where: 'id = ?', whereArgs: [snippet.id]);

  Future<void> delete(String id) async =>
      db.delete('snippets', where: 'id = ?', whereArgs: [id]);
}

import '../database/database_helper.dart';
import '../models/snippet.dart';
import '../models/activity.dart';

class SnippetRepository {
  final db = DatabaseHelper();

  Future<List<Snippet>> getAll() => db.getSnippets();

  Future<void> create(Snippet snippet) async {
    await db.insertSnippet(snippet);
    await db.insertActivity(Activity(type: ActivityType.snippetCreated));
  }

  Future<void> update(Snippet snippet) => db.updateSnippet(snippet);

  Future<void> delete(String id) => db.deleteSnippet(id);
}

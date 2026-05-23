import '../../../core/database/database_helper.dart';
import '../../../models/snippet.dart';
import '../../../models/activity.dart';
import '../interfaces/snippet_repository.dart';

class SnippetRepositoryImpl implements SnippetRepository {
  final DatabaseHelper _db;
  SnippetRepositoryImpl(this._db);

  @override
  Future<List<Snippet>> getAll() => _db.snippets.getAll();

  @override
  Future<void> create(Snippet snippet) async {
    await _db.snippets.insert(snippet);
    await _db.activities.insert(Activity(type: ActivityType.snippetCreated));
  }

  @override
  Future<void> update(Snippet snippet) => _db.snippets.update(snippet);

  @override
  Future<void> delete(String id) => _db.snippets.delete(id);
}

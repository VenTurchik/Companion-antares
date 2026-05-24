import '../../../core/database/database_helper.dart';
import '../../../models/snippet.dart';
import '../../../models/activity.dart';
import '../interfaces/snippet_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';
import '../../../services/app_store.dart';

class SnippetRepositoryImpl implements SnippetRepository {
  final DatabaseHelper _db;
  final AppStore _store;
  final SnippetRemoteSource _remote;

  SnippetRepositoryImpl(this._db, this._store, AntaresNetworkAdapter adapter)
      : _remote = SnippetRemoteSource(adapter);

  bool get _useRemote => _store.isRemote;

  @override
  Future<List<Snippet>> getAll() async {
    if (_useRemote) {
      final remote = await _remote.getAll();
      return remote ?? [];
    }
    return _db.snippets.getAll();
  }

  @override
  Future<void> create(Snippet snippet) async {
    if (_useRemote) {
      await _remote.create(snippet);
      return;
    }
    await _db.snippets.insert(snippet);
    await _db.activities.insert(Activity(type: ActivityType.snippetCreated));
  }

  @override
  Future<void> update(Snippet snippet) async {
    if (_useRemote) {
      await _remote.update(snippet);
      return;
    }
    await _db.snippets.update(snippet);
  }

  @override
  Future<void> delete(String id) async {
    if (_useRemote) {
      await _remote.delete(id);
      return;
    }
    await _db.snippets.delete(id);
  }
}

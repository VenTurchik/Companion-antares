import '../../../core/database/database_helper.dart';
import '../../../models/snippet.dart';
import '../../../models/activity.dart';
import '../interfaces/snippet_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';

class SnippetRepositoryImpl implements SnippetRepository {
  final DatabaseHelper _db;
  final AntaresNetworkAdapter? _adapter;
  final bool _useRemote;
  SnippetRemoteSource? _remote;

  SnippetRepositoryImpl(this._db, {AntaresNetworkAdapter? adapter, bool useRemote = false})
      : _adapter = adapter,
        _useRemote = useRemote {
    if (adapter != null) _remote = SnippetRemoteSource(adapter);
  }

  bool get _shouldUseRemote {
    final a = _adapter;
    return _useRemote && a != null && a.isConnected;
  }

  @override
  Future<List<Snippet>> getAll() async {
    if (_shouldUseRemote) {
      final remote = await _remote!.getAll();
      if (remote != null) return remote;
    }
    return _db.snippets.getAll();
  }

  @override
  Future<void> create(Snippet snippet) async {
    await _db.snippets.insert(snippet);
    await _db.activities.insert(Activity(type: ActivityType.snippetCreated));
    if (_shouldUseRemote) {
      await _remote!.create(snippet);
    }
  }

  @override
  Future<void> update(Snippet snippet) async {
    await _db.snippets.update(snippet);
    if (_shouldUseRemote) {
      await _remote!.update(snippet);
    }
  }

  @override
  Future<void> delete(String id) async {
    await _db.snippets.delete(id);
    if (_shouldUseRemote) {
      await _remote!.delete(id);
    }
  }
}

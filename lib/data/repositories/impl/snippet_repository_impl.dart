import 'package:uuid/uuid.dart';
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
      if (remote == null) return [];
      final noteMappings = await _db.idMappings.getAllMappings('note');
      final snippetMappings = await _db.idMappings.getAllMappings('snippet');
      final result = <Snippet>[];
      for (final s in remote) {
        final localId = snippetMappings[s.id];
        final localNoteId =
            s.noteId != null ? noteMappings[s.noteId] : null;
        if (localId != null) {
          result.add(Snippet(
            id: localId,
            title: s.title,
            code: s.code,
            language: s.language,
            tags: s.tags,
            noteId: localNoteId ?? s.noteId,
            createdAt: s.createdAt,
          ));
        } else {
          final newId = const Uuid().v4();
          await _db.idMappings.save(newId, s.id, 'snippet');
          result.add(Snippet(
            id: newId,
            title: s.title,
            code: s.code,
            language: s.language,
            tags: s.tags,
            noteId: localNoteId ?? s.noteId,
            createdAt: s.createdAt,
          ));
        }
      }
      return result;
    }
    return _db.snippets.getAll();
  }

  Future<Map<String, dynamic>> _prepareSnippetData(Snippet snippet) async {
    final data = snippet.toMap();
    if (snippet.noteId != null) {
      final remoteNoteId =
          await _db.idMappings.getRemoteId('note', snippet.noteId!);
      if (remoteNoteId != null) {
        data['noteId'] = remoteNoteId;
      }
    }
    return data;
  }

  @override
  Future<void> create(Snippet snippet) async {
    if (_useRemote) {
      final data = await _prepareSnippetData(snippet);
      final response = await _remote.create(data);
      final remoteId = response?['id']?.toString() ?? snippet.id;
      await _db.idMappings.save(snippet.id, remoteId, 'snippet');
      return;
    }
    await _db.snippets.insert(snippet);
    await _db.activities.insert(Activity(type: ActivityType.snippetCreated));
  }

  @override
  Future<void> update(Snippet snippet) async {
    if (_useRemote) {
      final remoteId =
          await _db.idMappings.getRemoteId('snippet', snippet.id) ?? snippet.id;
      final data = await _prepareSnippetData(snippet);
      await _remote.update(remoteId, data);
      return;
    }
    await _db.snippets.update(snippet);
  }

  @override
  Future<void> delete(String id) async {
    if (_useRemote) {
      final remoteId =
          await _db.idMappings.getRemoteId('snippet', id) ?? id;
      await _remote.delete(remoteId);
      await _db.idMappings.deleteByLocalId('snippet', id);
      return;
    }
    await _db.snippets.delete(id);
  }
}

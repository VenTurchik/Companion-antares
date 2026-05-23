import '../../../core/database/database_helper.dart';
import '../../../models/note.dart';
import '../../../models/activity.dart';
import '../interfaces/note_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';

class NoteRepositoryImpl implements NoteRepository {
  final DatabaseHelper _db;
  final AntaresNetworkAdapter? _adapter;
  final bool _useRemote;
  NoteRemoteSource? _remote;

  NoteRepositoryImpl(this._db, {AntaresNetworkAdapter? adapter, bool useRemote = false})
      : _adapter = adapter,
        _useRemote = useRemote {
    if (adapter != null) _remote = NoteRemoteSource(adapter);
  }

  bool get _shouldUseRemote {
    final a = _adapter;
    return _useRemote && a != null && a.isConnected;
  }

  @override
  Future<List<Note>> getAll() async {
    if (_shouldUseRemote) {
      final remote = await _remote!.getAll();
      if (remote != null) return remote;
    }
    return _db.notes.getAll();
  }

  @override
  Future<void> create(Note note) async {
    await _db.notes.insert(note);
    await _db.activities.insert(Activity(type: ActivityType.noteCreated));
    if (_shouldUseRemote) {
      await _remote!.create(note);
    }
  }

  @override
  Future<void> update(Note note) async {
    await _db.notes.update(note);
    if (_shouldUseRemote) {
      await _remote!.update(note);
    }
  }

  @override
  Future<void> delete(String id) async {
    await _db.notes.delete(id);
    if (_shouldUseRemote) {
      await _remote!.delete(id);
    }
  }
}

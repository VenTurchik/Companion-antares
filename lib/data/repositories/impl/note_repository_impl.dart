import '../../../core/database/database_helper.dart';
import '../../../models/note.dart';
import '../../../models/activity.dart';
import '../interfaces/note_repository.dart';
import '../remote/remote_sources.dart';
import '../../../services/network_adapter.dart';
import '../../../services/app_store.dart';

class NoteRepositoryImpl implements NoteRepository {
  final DatabaseHelper _db;
  final AppStore _store;
  final NoteRemoteSource _remote;

  NoteRepositoryImpl(this._db, this._store, AntaresNetworkAdapter adapter)
      : _remote = NoteRemoteSource(adapter);

  bool get _useRemote => _store.isRemote;

  @override
  Future<List<Note>> getAll() async {
    if (_useRemote) {
      final remote = await _remote.getAll();
      return remote ?? [];
    }
    return _db.notes.getAll();
  }

  @override
  Future<void> create(Note note) async {
    if (_useRemote) {
      await _remote.create(note);
      return;
    }
    await _db.notes.insert(note);
    await _db.activities.insert(Activity(type: ActivityType.noteCreated));
  }

  @override
  Future<void> update(Note note) async {
    if (_useRemote) {
      await _remote.update(note);
      return;
    }
    await _db.notes.update(note);
  }

  @override
  Future<void> delete(String id) async {
    if (_useRemote) {
      await _remote.delete(id);
      return;
    }
    await _db.notes.delete(id);
  }
}

import 'package:uuid/uuid.dart';
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
      if (remote == null) return [];
      final taskMappings = await _db.idMappings.getAllMappings('task');
      final noteMappings = await _db.idMappings.getAllMappings('note');
      final result = <Note>[];
      for (final n in remote) {
        final localId = noteMappings[n.id];
        final localTaskId =
            n.taskId != null ? taskMappings[n.taskId] : null;
        if (localId != null) {
          result.add(Note(
            id: localId,
            title: n.title,
            content: n.content,
            taskId: localTaskId ?? n.taskId,
            createdAt: n.createdAt,
            updatedAt: n.updatedAt,
          ));
        } else {
          final newId = const Uuid().v4();
          await _db.idMappings.save(newId, n.id, 'note');
          result.add(Note(
            id: newId,
            title: n.title,
            content: n.content,
            taskId: localTaskId ?? n.taskId,
            createdAt: n.createdAt,
            updatedAt: n.updatedAt,
          ));
        }
      }
      return result;
    }
    return _db.notes.getAll();
  }

  Future<Map<String, dynamic>> _prepareNoteData(Note note) async {
    final data = note.toMap();
    if (note.taskId != null) {
      final remoteTaskId =
          await _db.idMappings.getRemoteId('task', note.taskId!);
      if (remoteTaskId != null) {
        data['taskId'] = remoteTaskId;
      }
    }
    return data;
  }

  @override
  Future<void> create(Note note) async {
    if (_useRemote) {
      final data = await _prepareNoteData(note);
      final response = await _remote.create(data);
      final remoteId = response?['id']?.toString() ?? note.id;
      await _db.idMappings.save(note.id, remoteId, 'note');
      return;
    }
    await _db.notes.insert(note);
    await _db.activities.insert(Activity(type: ActivityType.noteCreated));
  }

  @override
  Future<void> update(Note note) async {
    if (_useRemote) {
      final remoteId =
          await _db.idMappings.getRemoteId('note', note.id) ?? note.id;
      final data = await _prepareNoteData(note);
      await _remote.update(remoteId, data);
      return;
    }
    await _db.notes.update(note);
  }

  @override
  Future<void> delete(String id) async {
    if (_useRemote) {
      final remoteId =
          await _db.idMappings.getRemoteId('note', id) ?? id;
      await _remote.delete(remoteId);
      await _db.idMappings.deleteByLocalId('note', id);
      return;
    }
    await _db.notes.delete(id);
  }
}

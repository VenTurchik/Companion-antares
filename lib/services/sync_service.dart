import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/note.dart';
import '../models/snippet.dart';
import '../models/task.dart';
import '../models/task_column.dart';
import 'app_store.dart';
import 'network_adapter.dart';

enum SyncState { idle, syncing, done, error }

class SyncService extends ChangeNotifier {
  final AntaresNetworkAdapter _adapter;
  final DatabaseHelper _db;
  final AppStore _store;

  SyncService(this._adapter, this._db, this._store);

  SyncState _state = SyncState.idle;
  SyncState get state => _state;

  String _lastMessage = '';
  String get lastMessage => _lastMessage;

  Future<void> copyServerData() async {
    if (_state == SyncState.syncing) return;
    if (!_store.isRemote) {
      _lastMessage = 'Не подключено к серверу';
      _state = SyncState.error;
      notifyListeners();
      return;
    }

    _state = SyncState.syncing;
    _lastMessage = 'Копирование данных с сервера...';
    notifyListeners();

    try {
      await _copyKanban();
      await _copyNotes();
      await _copySnippets();

      await _store.markSynced();
      _lastMessage = 'Данные скопированы с сервера';
      _state = SyncState.done;
    } catch (e) {
      _lastMessage = 'Ошибка: $e';
      _state = SyncState.error;
    }
    notifyListeners();
  }

  Future<void> _copyKanban() async {
    final data = await _adapter.syncKanban();
    if (data == null) return;
    final columns = data['columns'];
    if (columns is! List) return;

    final allTasks = await _db.tasks.getAll();
    for (final t in allTasks) {
      await _db.tasks.delete(t.id);
    }
    final allCols = await _db.taskColumns.getAll();
    for (final c in allCols) {
      await _db.taskColumns.delete(c.id);
    }

    for (final col in columns) {
      final colMap = col as Map<String, dynamic>;
      final column = TaskColumn.fromMap(colMap);
      await _db.taskColumns.insert(column);

      final tasks = colMap['tasks'];
      if (tasks is List) {
        for (final t in tasks) {
          final task = Task.fromMap(t as Map<String, dynamic>);
          await _db.tasks.insert(task);
        }
      }
    }
  }

  Future<void> _copyNotes() async {
    final data = await _adapter.syncNotes();
    if (data == null) return;
    final list = data['notes'];
    if (list is! List) return;

    final existing = await _db.notes.getAll();
    for (final n in existing) {
      await _db.notes.delete(n.id);
    }

    for (final e in list) {
      final note = Note.fromMap(e as Map<String, dynamic>);
      await _db.notes.insert(note);
    }
  }

  Future<void> _copySnippets() async {
    final data = await _adapter.syncSnippets();
    if (data == null) return;
    final list = data['snippets'];
    if (list is! List) return;

    final existing = await _db.snippets.getAll();
    for (final s in existing) {
      await _db.snippets.delete(s.id);
    }

    for (final e in list) {
      final snippet = Snippet.fromMap(e as Map<String, dynamic>);
      await _db.snippets.insert(snippet);
    }
  }

  void resetState() {
    _state = SyncState.idle;
    _lastMessage = '';
    notifyListeners();
  }
}

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

  Future<void> syncAll() async {
    if (_state == SyncState.syncing) return;
    if (!_adapter.isConnected) {
      _lastMessage = 'Нет подключения к серверу';
      _state = SyncState.error;
      notifyListeners();
      return;
    }

    _state = SyncState.syncing;
    _lastMessage = 'Синхронизация...';
    notifyListeners();

    try {
      await _syncKanban();
      await _syncNotes();
      await _syncSnippets();

      await _store.markSynced();
      _lastMessage = 'Синхронизация завершена';
      _state = SyncState.done;
    } catch (e) {
      _lastMessage = 'Ошибка: $e';
      _state = SyncState.error;
    }
    notifyListeners();
  }

  Future<void> _syncKanban() async {
    final data = await _adapter.syncKanban();
    if (data == null) return;
    final columns = data['columns'];
    if (columns is! List) return;

    for (final col in columns) {
      final colMap = col as Map<String, dynamic>;
      final colId = colMap['id']?.toString() ?? '';
      final existingCol = await _db.taskColumns.getById(colId);
      if (existingCol != null) {
        await _db.taskColumns.update(TaskColumn.fromMap(colMap));
      } else {
        await _db.taskColumns.insert(TaskColumn.fromMap(colMap));
      }

      final tasks = colMap['tasks'];
      if (tasks is List) {
        for (final t in tasks) {
          final taskMap = t as Map<String, dynamic>;
          final taskId = taskMap['id']?.toString() ?? '';
          final existing = await _db.tasks.getById(taskId);
          if (existing != null) {
            await _db.tasks.update(Task.fromMap(taskMap));
          } else {
            await _db.tasks.insert(Task.fromMap(taskMap));
          }
        }
      }
    }
  }

  Future<void> _syncNotes() async {
    final data = await _adapter.syncNotes();
    if (data == null) return;
    final list = data['notes'];
    if (list is! List) return;
    for (final e in list) {
      final map = e as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      final existing = await _db.notes.getById(id);
      if (existing != null) {
        await _db.notes.update(Note.fromMap(map));
      } else {
        await _db.notes.insert(Note.fromMap(map));
      }
    }
  }

  Future<void> _syncSnippets() async {
    final data = await _adapter.syncSnippets();
    if (data == null) return;
    final list = data['snippets'];
    if (list is! List) return;
    for (final e in list) {
      final map = e as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      final existing = await _db.snippets.getById(id);
      if (existing != null) {
        await _db.snippets.update(Snippet.fromMap(map));
      } else {
        await _db.snippets.insert(Snippet.fromMap(map));
      }
    }
  }

  void resetState() {
    _state = SyncState.idle;
    _lastMessage = '';
    notifyListeners();
  }
}

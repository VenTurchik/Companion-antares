import '../../../models/task.dart';
import '../../../models/task_column.dart';
import '../../../models/note.dart';
import '../../../models/snippet.dart';
import '../../../services/network_adapter.dart';

/// Удалённый источник данных для задач (канбана).
class TaskRemoteSource {
  final AntaresNetworkAdapter _adapter;
  TaskRemoteSource(this._adapter);

  Future<List<Task>?> getAll() async {
    final data = await _adapter.syncKanban();
    if (data == null) return null;
    final columns = data['columns'];
    if (columns is! List) return null;
    final tasks = <Task>[];
    for (final col in columns) {
      final colTasks = (col as Map<String, dynamic>)['tasks'];
      if (colTasks is List) {
        for (final t in colTasks) {
          tasks.add(Task.fromMap(t as Map<String, dynamic>));
        }
      }
    }
    return tasks;
  }

  Future<Map<String, dynamic>?> create(Map<String, dynamic> data) =>
      _adapter.postWithBody('/api/v1/kanban/tasks', data);
  Future<void> update(String id, Map<String, dynamic> data) =>
      _adapter.put('/api/v1/kanban/tasks/$id', data);
  Future<void> move(String id, String newStatus) {
    print('Перемещаю задачу $id в статус: $newStatus');
    return _adapter.put('/api/v1/kanban/tasks/$id/move', {'status': newStatus});
  }
  Future<void> delete(String id) => _adapter.delete('/api/v1/kanban/tasks/$id');
}

/// Удалённый источник данных для колонок.
class TaskColumnRemoteSource {
  final AntaresNetworkAdapter _adapter;
  TaskColumnRemoteSource(this._adapter);

  Future<List<TaskColumn>?> getAll() async {
    final data = await _adapter.syncKanban();
    if (data == null) return null;
    final list = data['columns'];
    if (list is! List) return null;
    return list.map((e) => TaskColumn.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> createColumn(Map<String, dynamic> data) =>
      _adapter.postWithBody('/api/v1/kanban/columns', data);

  Future<void> deleteColumn(String statusKey) =>
      _adapter.delete('/api/v1/kanban/columns/$statusKey');

  Future<void> updateColumn(String statusKey, Map<String, dynamic> data) =>
      _adapter.put('/api/v1/kanban/columns/$statusKey', data);
}

/// Удалённый источник данных для заметок.
class NoteRemoteSource {
  final AntaresNetworkAdapter _adapter;
  NoteRemoteSource(this._adapter);

  Future<List<Note>?> getAll() async {
    final data = await _adapter.syncNotes();
    if (data == null) return null;
    return data.map((e) => Note.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> create(Map<String, dynamic> data) =>
      _adapter.postWithBody('/api/v1/notes', data);
  Future<void> update(String id, Map<String, dynamic> data) =>
      _adapter.put('/api/v1/notes/$id', data);
  Future<void> delete(String id) => _adapter.delete('/api/v1/notes/$id');
}

/// Удалённый источник данных для сниппетов.
class SnippetRemoteSource {
  final AntaresNetworkAdapter _adapter;
  SnippetRemoteSource(this._adapter);

  Future<List<Snippet>?> getAll() async {
    final data = await _adapter.syncSnippets();
    if (data == null) return null;
    return data.map((e) => Snippet.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> create(Map<String, dynamic> data) =>
      _adapter.postWithBody('/api/v1/snippets', data);
  Future<void> update(String id, Map<String, dynamic> data) =>
      _adapter.put('/api/v1/snippets/$id', data);
  Future<void> delete(String id) => _adapter.delete('/api/v1/snippets/$id');
}

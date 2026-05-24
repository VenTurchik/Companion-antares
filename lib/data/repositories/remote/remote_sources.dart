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

  Future<void> create(Task task) => _adapter.post('/api/v1/kanban/tasks', task.toMap());
  Future<void> update(Task task) => _adapter.put('/api/v1/kanban/tasks/${task.id}', task.toMap());
  Future<void> delete(String id) => _adapter.delete('/api/v1/kanban/tasks/$id');
}

/// Удалённый источник данных для колонок.
class TaskColumnRemoteSource {
  final AntaresNetworkAdapter _adapter;
  TaskColumnRemoteSource(this._adapter);

  Future<List<TaskColumn>?> getAll() async {
    final data = await _adapter.syncKanban();
    if (data == null) return null;
    print('Ответ сервера (columns): $data');
    final list = data['columns'];
    if (list is! List) return null;
    return list.map((e) => TaskColumn.fromMap(e as Map<String, dynamic>)).toList();
  }
}

/// Удалённый источник данных для заметок.
class NoteRemoteSource {
  final AntaresNetworkAdapter _adapter;
  NoteRemoteSource(this._adapter);

  Future<List<Note>?> getAll() async {
    final data = await _adapter.syncNotes();
    if (data == null) return null;
    final list = data['notes'];
    if (list is! List) return null;
    return list.map((e) => Note.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> create(Note note) => _adapter.post('/api/v1/notes', note.toMap());
  Future<void> update(Note note) => _adapter.put('/api/v1/notes/${note.id}', note.toMap());
  Future<void> delete(String id) => _adapter.delete('/api/v1/notes/$id');
}

/// Удалённый источник данных для сниппетов.
class SnippetRemoteSource {
  final AntaresNetworkAdapter _adapter;
  SnippetRemoteSource(this._adapter);

  Future<List<Snippet>?> getAll() async {
    final data = await _adapter.syncSnippets();
    if (data == null) return null;
    final list = data['snippets'];
    if (list is! List) return null;
    return list.map((e) => Snippet.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> create(Snippet snippet) => _adapter.post('/api/v1/snippets', snippet.toMap());
  Future<void> update(Snippet snippet) => _adapter.put('/api/v1/snippets/${snippet.id}', snippet.toMap());
  Future<void> delete(String id) => _adapter.delete('/api/v1/snippets/$id');
}

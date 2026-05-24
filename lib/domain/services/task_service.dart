import '../../models/task.dart';
import '../../models/task_column.dart';
import '../../models/note.dart';
import '../../models/snippet.dart';
import '../../data/repositories/interfaces/task_repository.dart';
import '../../data/repositories/interfaces/note_repository.dart';
import '../../data/repositories/interfaces/snippet_repository.dart';
import '../../data/repositories/interfaces/task_column_repository.dart';
import '../../core/errors/app_exception.dart';
import '../../core/constants.dart';

/// Бизнес-логика работы с задачами.
/// Координирует несколько репозиториев и содержит правила предметной области.
class TaskService {
  final TaskRepository _taskRepo;
  final NoteRepository _noteRepo;
  final SnippetRepository _snippetRepo;
  final TaskColumnRepository _columnRepo;

  TaskService(this._taskRepo, this._noteRepo, this._snippetRepo, this._columnRepo);

  // ---- Задачи ----

  Future<List<Task>> getAllTasks() => _taskRepo.getAll();

  Future<List<Task>> getBoardTasks() async {
    final tasks = await _taskRepo.getAll();
    return tasks.where((t) => t.status != TaskStatusKeys.done).toList();
  }

  Future<List<Task>> getArchiveTasks() async {
    final tasks = await _taskRepo.getAll();
    return tasks.where((t) => t.status == TaskStatusKeys.done).toList();
  }

  Future<Task?> getTaskById(String id) => _taskRepo.getById(id);

  Future<void> createTask(Task task) => _taskRepo.create(task);

  /// Перемещает задачу в другую колонку. Проверяет блокировку inProgress.
  Future<void> moveTask(Task task, String newStatusKey, {bool timerRunning = false}) async {
    if (newStatusKey == TaskStatusKeys.inProgress && !timerRunning) {
      throw TimerNotRunningException();
    }
    task.status = newStatusKey;
    await _taskRepo.move(task.id, newStatusKey);
  }

  /// Удаляет задачу и связанные заметки.
  Future<void> deleteTaskWithRelations(String taskId) async {
    final notes = await _noteRepo.getAll();
    for (final note in notes.where((n) => n.taskId == taskId)) {
      await _noteRepo.delete(note.id);
    }
    await _taskRepo.delete(taskId);
  }

  Future<void> updateTask(Task task) => _taskRepo.update(task);

  Future<void> deleteTask(String id) => _taskRepo.delete(id);

  // ---- Колонки ----

  Future<List<TaskColumn>> getColumns() => _columnRepo.getAll();

  Future<List<TaskColumn>> getBoardColumns() async {
    final cols = await _columnRepo.getAll();
    return cols.where((c) => c.statusKey != TaskStatusKeys.done).toList();
  }

  Future<void> addColumn(TaskColumn column) => _columnRepo.insert(column);

  Future<void> deleteColumn(TaskColumn column) async {
    const defaultKeys = {'todo', 'in_progress', 'done'};
    if (column.isDefault || defaultKeys.contains(column.statusKey)) {
      throw CannotDeleteDefaultColumnException();
    }
    final tasks = await _taskRepo.getAll();
    for (final t in tasks.where((t) => t.status == column.statusKey)) {
      await _taskRepo.delete(t.id);
    }
    await _columnRepo.delete(column);
  }

  Future<void> updateColumn(TaskColumn column) => _columnRepo.update(column);

  // ---- Заметки / Сниппеты (связанные) ----

  Future<List<Note>> getAllNotes() => _noteRepo.getAll();

  Future<List<Snippet>> getAllSnippets() => _snippetRepo.getAll();

  /// Связанные заметки для задачи.
  Future<List<Note>> getNotesForTask(String taskId) async {
    final notes = await _noteRepo.getAll();
    return notes.where((n) => n.taskId == taskId).toList();
  }

  /// Сниппеты, привязанные к заметкам конкретной задачи.
  Future<List<Snippet>> getSnippetsForTask(String taskId) async {
    final notes = await getNotesForTask(taskId);
    final noteIds = notes.map((n) => n.id).toSet();
    final all = await _snippetRepo.getAll();
    return all.where((s) => s.noteId != null && noteIds.contains(s.noteId)).toList();
  }

  /// Количество заметок на задачу.
  Future<Map<String, int>> getNoteCounts() async {
    final notes = await _noteRepo.getAll();
    final map = <String, int>{};
    for (final n in notes) {
      if (n.taskId != null) map[n.taskId!] = (map[n.taskId!] ?? 0) + 1;
    }
    return map;
  }

  /// Количество сниппетов на задачу (через заметки).
  Future<Map<String, int>> getSnippetCounts() async {
    final notes = await _noteRepo.getAll();
    final noteIds = notes.where((n) => n.taskId != null).map((n) => n.id).toSet();
    final snippets = await _snippetRepo.getAll();
    final map = <String, int>{};
    for (final s in snippets) {
      if (s.noteId != null && noteIds.contains(s.noteId)) {
        final note = notes.firstWhere((n) => n.id == s.noteId);
        if (note.taskId != null) {
          map[note.taskId!] = (map[note.taskId!] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  // ---- Заметки / Сниппеты (CRUD) ----

  Future<void> createNote(Note note) => _noteRepo.create(note);
  Future<void> updateNote(Note note) => _noteRepo.update(note);
  Future<void> deleteNote(String id) => _noteRepo.delete(id);

  Future<void> createSnippet(Snippet snippet) => _snippetRepo.create(snippet);
  Future<void> updateSnippet(Snippet snippet) => _snippetRepo.update(snippet);
  Future<void> deleteSnippet(String id) => _snippetRepo.delete(id);
}

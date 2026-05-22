import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import '../models/task_column.dart';
import '../models/note.dart';
import '../models/snippet.dart';
import '../models/activity.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    if (_db != null) return;
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'companion.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        taskNumber TEXT NOT NULL DEFAULT 'TASK-0001',
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'todo',
        commitHash TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        completedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE task_columns (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        statusKey TEXT NOT NULL,
        colorValue INTEGER NOT NULL DEFAULT 0xFF9E9E9E,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        isDefault INTEGER NOT NULL DEFAULT 0
      )
    ''');
    for (final col in TaskColumn.defaults()) {
      await db.insert('task_columns', col.toMap());
    }
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        taskId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (taskId) REFERENCES tasks(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE snippets (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        code TEXT NOT NULL,
        language TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '[]',
        noteId TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (noteId) REFERENCES notes(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE work_sessions (
        id TEXT PRIMARY KEY,
        startTime TEXT NOT NULL,
        endTime TEXT,
        durationSeconds INTEGER NOT NULL DEFAULT 0,
        taskId TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final cols = await db.rawQuery('PRAGMA table_info(tasks)');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('taskNumber')) {
        await db.execute(
            "ALTER TABLE tasks ADD COLUMN taskNumber TEXT NOT NULL DEFAULT 'TASK-0001'");
      }
      if (!colNames.contains('completedAt')) {
        await db.execute(
            'ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS work_sessions (
          id TEXT PRIMARY KEY,
          startTime TEXT NOT NULL,
          endTime TEXT,
          durationSeconds INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 3) {
      final cols = await db.rawQuery('PRAGMA table_info(work_sessions)');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('taskId')) {
        await db.execute(
            'ALTER TABLE work_sessions ADD COLUMN taskId TEXT');
      }
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_columns (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          statusKey TEXT NOT NULL,
          colorValue INTEGER NOT NULL DEFAULT 0xFF9E9E9E,
          sortOrder INTEGER NOT NULL DEFAULT 0,
          isDefault INTEGER NOT NULL DEFAULT 0
        )
      ''');
      final count = sqflite.Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM task_columns'));
      if (count == 0) {
        for (final col in TaskColumn.defaults()) {
          await db.insert('task_columns', col.toMap());
        }
      }
    }
  }

  // ---- Task Columns ----
  Future<List<TaskColumn>> getTaskColumns() async {
    final maps = await db.query('task_columns', orderBy: 'sortOrder ASC');
    return maps.map((m) => TaskColumn.fromMap(m)).toList();
  }

  Future<void> insertTaskColumn(TaskColumn col) async =>
      db.insert('task_columns', col.toMap());

  Future<void> deleteTaskColumn(String id) async =>
      db.delete('task_columns', where: 'id = ?', whereArgs: [id]);

  // ---- Tasks ----
  Future<List<Task>> getTasks() async {
    final maps = await db.query('tasks', orderBy: 'updatedAt DESC');
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<void> insertTask(Task task) async =>
      db.insert('tasks', task.toMap());

  Future<void> updateTask(Task task) async {
    task.updatedAt = DateTime.now();
    db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(String id) async =>
      db.delete('tasks', where: 'id = ?', whereArgs: [id]);

  // ---- Notes ----
  Future<List<Note>> getNotes() async {
    final maps = await db.query('notes', orderBy: 'updatedAt DESC');
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<void> insertNote(Note note) async =>
      db.insert('notes', note.toMap());

  Future<void> updateNote(Note note) async {
    note.updatedAt = DateTime.now();
    db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> deleteNote(String id) async =>
      db.delete('notes', where: 'id = ?', whereArgs: [id]);

  // ---- Snippets ----
  Future<List<Snippet>> getSnippets() async {
    final maps = await db.query('snippets', orderBy: 'createdAt DESC');
    return maps.map((m) => Snippet.fromMap(m)).toList();
  }

  Future<void> insertSnippet(Snippet snippet) async =>
      db.insert('snippets', snippet.toMap());

  Future<void> updateSnippet(Snippet snippet) async =>
      db.update('snippets', snippet.toMap(),
          where: 'id = ?', whereArgs: [snippet.id]);

  Future<void> deleteSnippet(String id) async =>
      db.delete('snippets', where: 'id = ?', whereArgs: [id]);

  // ---- Activities ----
  Future<List<Activity>> getActivities() async {
    final maps = await db.query('activities', orderBy: 'timestamp DESC');
    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  Future<List<Activity>> getActivitiesBetween(
    DateTime start, DateTime end,
  ) async {
    final maps = await db.query(
      'activities',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  Future<void> insertActivity(Activity activity) async =>
      db.insert('activities', activity.toMap());
}

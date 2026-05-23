import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Миграции схемы базы данных.
/// Каждая миграция идемпотентна (проверяет существование колонок/таблиц).
class Migrations {
  /// Создание всех таблиц с нуля.
  static Future<void> onCreate(Database db, int version) async {
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
    await _createTaskColumnsWithDefaults(db);
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

  /// Прогрев версий с 1 до 4.
  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _v1ToV2(db);
    if (oldVersion < 3) await _v2ToV3(db);
    if (oldVersion < 4) await _v3ToV4(db);
  }

  static Future<void> _v1ToV2(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(tasks)');
    final names = cols.map((c) => c['name'] as String).toSet();
    if (!names.contains('taskNumber')) {
      await db.execute(
          "ALTER TABLE tasks ADD COLUMN taskNumber TEXT NOT NULL DEFAULT 'TASK-0001'");
    }
    if (!names.contains('completedAt')) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
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

  static Future<void> _v2ToV3(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(work_sessions)');
    final names = cols.map((c) => c['name'] as String).toSet();
    if (!names.contains('taskId')) {
      await db.execute('ALTER TABLE work_sessions ADD COLUMN taskId TEXT');
    }
  }

  static Future<void> _v3ToV4(Database db) async {
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
    final count = (await db.rawQuery('SELECT COUNT(*) AS c FROM task_columns')).first['c'] as int;
    if (count == 0) {
      await _createTaskColumnsWithDefaults(db);
    }
  }

  static Future<void> _createTaskColumnsWithDefaults(Database db) async {
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
    final cols = [
      {'id': const Uuid().v4(), 'name': 'To Do', 'statusKey': 'todo', 'colorValue': 0xFF9E9E9E, 'sortOrder': 0, 'isDefault': 1},
      {'id': const Uuid().v4(), 'name': 'In Progress', 'statusKey': 'inProgress', 'colorValue': 0xFF2196F3, 'sortOrder': 1, 'isDefault': 1},
      {'id': const Uuid().v4(), 'name': 'Done', 'statusKey': 'done', 'colorValue': 0xFF4CAF50, 'sortOrder': 2, 'isDefault': 1},
    ];
    for (final col in cols) {
      await db.insert('task_columns', col);
    }
  }
}

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'migrations.dart';
import 'tables/tasks_table.dart';
import 'tables/notes_table.dart';
import 'tables/snippets_table.dart';
import 'tables/activities_table.dart';
import 'tables/work_sessions_table.dart';
import 'tables/task_columns_table.dart';
import 'tables/id_mappings_table.dart';
import '../constants.dart';

/// Координатор доступа к SQLite.
/// Инициализирует FFI, открывает БД, проводит миграции и предоставляет
/// объекты для работы с каждой таблицей (SRP: делегирует операции таблицам).
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  sqflite.Database? _db;
  sqflite.Database get db => _db!;
  String? _dbPath;

  late final TasksTable tasks;
  late final NotesTable notes;
  late final SnippetsTable snippets;
  late final ActivitiesTable activities;
  late final WorkSessionsTable workSessions;
  late final TaskColumnsTable taskColumns;
  late final IdMappingsTable idMappings;

  String? get dbPath => _dbPath;

  /// Удаляет все данные из всех таблиц.
  Future<void> clearAll() async {
    await db.delete('snippets');
    await db.delete('notes');
    await db.delete('tasks');
    await db.delete('task_columns');
    await db.delete('work_sessions');
    await db.delete('activities');
  }

  /// Открывает (или создаёт) БД и проводит миграции до текущей версии.
  Future<void> init() async {
    if (_db != null) return;
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.dbName);
    _dbPath = path;
    _db = await sqflite.openDatabase(
      path,
      version: 5,
      onCreate: Migrations.onCreate,
      onUpgrade: Migrations.onUpgrade,
    );
    // Инициализация табличных объектов
    tasks = TasksTable(db);
    notes = NotesTable(db);
    snippets = SnippetsTable(db);
    activities = ActivitiesTable(db);
    workSessions = WorkSessionsTable(db);
    taskColumns = TaskColumnsTable(db);
    idMappings = IdMappingsTable(db);
  }
}

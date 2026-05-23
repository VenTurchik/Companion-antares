import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'core/database/database_helper.dart';
import 'data/repositories/impl/task_repository_impl.dart';
import 'data/repositories/impl/note_repository_impl.dart';
import 'data/repositories/impl/snippet_repository_impl.dart';
import 'data/repositories/impl/work_session_repository_impl.dart';
import 'data/repositories/impl/activity_repository_impl.dart';
import 'data/repositories/impl/task_column_repository_impl.dart';
import 'data/repositories/interfaces/task_repository.dart';
import 'data/repositories/interfaces/note_repository.dart';
import 'data/repositories/interfaces/snippet_repository.dart';
import 'data/repositories/interfaces/work_session_repository.dart';
import 'data/repositories/interfaces/activity_repository.dart';
import 'data/repositories/interfaces/task_column_repository.dart';
import 'domain/services/task_service.dart';
import 'domain/services/metrics_service.dart';
import 'services/settings_service.dart';
import 'services/work_timer_service.dart';
import 'services/app_store.dart';
import 'services/tray_service.dart';
import 'services/network_adapter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await initializeDateFormatting('ru');

  // === Инициализация базы данных ===
  final db = DatabaseHelper();
  await db.init();

  // === Локальные репозитории ===
  final WorkSessionRepository workRepo = WorkSessionRepositoryImpl(db);
  final ActivityRepository activityRepo = ActivityRepositoryImpl(db);

  // === Хранилище (нужно для адаптера) ===
  final store = AppStore(workRepo, activityRepo);
  await store.init();

  // === Сетевой адаптер ===
  final networkAdapter = AntaresNetworkAdapter(store);

  // === Репозитории с поддержкой удалённого доступа ===
  final TaskRepository taskRepo = TaskRepositoryImpl(db, adapter: networkAdapter, useRemote: true);
  final NoteRepository noteRepo = NoteRepositoryImpl(db, adapter: networkAdapter, useRemote: true);
  final SnippetRepository snippetRepo = SnippetRepositoryImpl(db, adapter: networkAdapter, useRemote: true);
  final TaskColumnRepository columnRepo = TaskColumnRepositoryImpl(db, adapter: networkAdapter, useRemote: true);

  // === Сервисы ===
  final taskService = TaskService(taskRepo, noteRepo, snippetRepo, columnRepo);
  final metricsService = MetricsService(activityRepo, workRepo, taskRepo);

  // === ChangeNotifier-сервисы ===
  final settings = SettingsService();
  await settings.init();
  final timer = WorkTimerService(workRepo, taskRepo);
  await timer.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: timer),
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: networkAdapter),
        Provider<TaskService>.value(value: taskService),
        Provider<MetricsService>.value(value: metricsService),
      ],
      child: const CompanionApp(),
    ),
  );

  // === Системный трей ===
  final tray = TrayService();
  tray.onTimerToggle = () {
    if (timer.isRunning) {
      timer.stop();
    } else {
      timer.start();
    }
  };
  await tray.init();

  timer.addListener(() => tray.updateTimerState(timer.isRunning));
}

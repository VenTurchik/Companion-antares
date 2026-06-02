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
import 'services/ping_service.dart';
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

  // === Ping-сервис и сетевой адаптер ===
  final pingService = PingService(store);
  final networkAdapter = AntaresNetworkAdapter(store, pingService);

  // === Репозитории с поддержкой двух режимов ===
  final TaskRepository taskRepo = TaskRepositoryImpl(db, store, networkAdapter);
  final NoteRepository noteRepo = NoteRepositoryImpl(db, store, networkAdapter);
  final SnippetRepository snippetRepo = SnippetRepositoryImpl(db, store, networkAdapter);
  final TaskColumnRepository columnRepo = TaskColumnRepositoryImpl(db, store, networkAdapter);

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
        ChangeNotifierProvider.value(value: pingService),
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

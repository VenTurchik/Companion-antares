import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'database/database_helper.dart';
import 'services/settings_service.dart';
import 'services/work_timer_service.dart';
import 'services/app_store.dart';
import 'services/tray_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await initializeDateFormatting('ru');
  await DatabaseHelper().init();
  final settings = SettingsService();
  await settings.init();
  final timer = WorkTimerService();
  await timer.init();
  final store = AppStore();
  await store.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: timer),
        ChangeNotifierProvider.value(value: store),
      ],
      child: const CompanionApp(),
    ),
  );

  // инициализация системного трея
  final tray = TrayService();
  tray.onTimerToggle = () {
    if (timer.isRunning) {
      timer.stop();
    } else {
      timer.start();
    }
  };
  await tray.init();

  // синхронизация меню трея с состоянием таймера
  timer.addListener(() => tray.updateTimerState(timer.isRunning));
}

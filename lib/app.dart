import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'services/work_timer_service.dart';
import 'domain/services/task_service.dart';
import 'core/constants.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/kanban/kanban_screen.dart';
import 'screens/notes/note_list_screen.dart';
import 'screens/snippets/snippet_list_screen.dart';
import 'screens/metrics/metrics_screen.dart';
import 'screens/settings/settings_screen.dart';

/// Корневой виджет приложения.
class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          surfaceTintColor: Color(0xFF1E1E1E),
        ),
      ),
      home: const MainShell(),
    );
  }
}

/// Основной каркас с NavigationRail и таймерной панелью.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = context.watch<WorkTimerService>();
    return Scaffold(
      body: Row(
        children: [
          Column(
            children: [
              _buildTimerPanel(timer, theme),
              Expanded(
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: theme.brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  indicatorColor: Colors.indigo.shade100,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.auto_awesome,
                        color: Colors.indigo.shade400, size: 28),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Дашборд'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.view_kanban_outlined),
                      selectedIcon: Icon(Icons.view_kanban),
                      label: Text('Канбан'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.description_outlined),
                      selectedIcon: Icon(Icons.description),
                      label: Text('Заметки'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.code_outlined),
                      selectedIcon: Icon(Icons.code),
                      label: Text('Сниппеты'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: Text('Метрики'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Настройки'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _screen()),
        ],
      ),
    );
  }

  Widget _screen() {
    switch (_index) {
      case 0: return DashboardScreen(onGoToTab: (i) => setState(() => _index = i));
      case 1: return const KanbanScreen();
      case 2: return const NoteListScreen();
      case 3: return const SnippetListScreen();
      case 4: return const MetricsScreen();
      case 5: return const SettingsScreen();
      default: return const SizedBox();
    }
  }

  Widget _buildTimerPanel(WorkTimerService timer, ThemeData theme) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: timer.isRunning
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timer.isRunning) ...[
            const Icon(Icons.circle, size: 10, color: Colors.green),
            const SizedBox(height: 4),
            Text(timer.elapsedFormatted,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (timer.linkedTask != null) ...[
              const SizedBox(height: 2),
              Text(timer.linkedTask!.taskNumber,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontSize: 9)),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: 60, height: 28,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.red.shade50),
                onPressed: timer.stop,
                child: const Icon(Icons.stop, size: 16),
              ),
            ),
          ] else ...[
            const Icon(Icons.play_circle_outline,
                size: 24, color: Colors.green),
            const SizedBox(height: 4),
            SizedBox(
              width: 60, height: 28,
              child: FilledButton(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => _startTimerWithTask(context, timer),
                child: const Icon(Icons.play_arrow, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startTimerWithTask(BuildContext context, WorkTimerService timer) async {
    final taskService = context.read<TaskService>();
    final tasks = await taskService.getAllTasks();
    if (!context.mounted) return;

    if (tasks.isEmpty) {
      timer.start();
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Запустить таймер'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Без задачи'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ...tasks.map((t) => ListTile(
                leading: Icon(Icons.task_alt,
                    color: t.status == TaskStatusKeys.done
                        ? Colors.green : Colors.orange),
                title: Text('${t.taskNumber} ${t.title}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                dense: true,
                onTap: () => Navigator.pop(ctx, t.id),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (result != null) {
      timer.start(taskId: result.isEmpty ? null : result);
    }
  }
}

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
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/network/network_screen.dart';
import 'services/app_store.dart';
import 'services/network_adapter.dart';
import 'services/loading_service.dart';

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
      ),
      home: settings.isOnboardingDone
          ? const MainShell()
          : const OnboardingScreen(),
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
    final destinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Дашборд'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.view_kanban_outlined),
        selectedIcon: Icon(Icons.view_kanban),
        label: Text('Канбан'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description),
        label: Text('Заметки'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.code_outlined),
        selectedIcon: Icon(Icons.code),
        label: Text('Сниппеты'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: Text('Подключение'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Настройки'),
      ),
    ];
    if (_index >= destinations.length) _index = destinations.length - 1;
    return Scaffold(
      body: Stack(
        children: [
          Row(
        children: [
          Column(
            children: [
              _buildTimerPanel(timer, theme),
              _buildConnectionIndicator(context, theme),
              Expanded(
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: theme.colorScheme.surface,
                  indicatorColor: theme.colorScheme.primaryContainer,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.auto_awesome,
                        color: Colors.indigo.shade400, size: 28),
                  ),
                  destinations: destinations,
                ),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _screen()),
        ],
      ),
          Consumer<LoadingService>(
            builder: (_, loader, __) {
              if (!loader.isLoading) return const SizedBox.shrink();
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LinearProgressIndicator(),
                      Container(
                        width: double.infinity,
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey.shade900
                            : Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(loader.message,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
      case 4: return const NetworkScreen();
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
            ? Colors.green.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
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

  Widget _buildConnectionIndicator(BuildContext context, ThemeData theme) {
    final store = context.watch<AppStore>();
    final adapter = context.watch<AntaresNetworkAdapter>();
    final connected = adapter.isConnected;
    return InkWell(
      onTap: () => setState(() => _index = 4),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: connected
              ? Colors.green.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.3),
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected ? Icons.cloud_done : Icons.cloud_outlined,
              size: 16,
              color: connected ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 2),
            Text(
              store.connectionLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontSize: 8, height: 1.2),
            ),
            if (connected && store.userRole != null) ...[
              const SizedBox(height: 1),
              Text(
                store.roleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 7,
                  color: Colors.grey,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
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

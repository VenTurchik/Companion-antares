import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/work_session.dart';
import '../../domain/services/task_service.dart';
import '../../domain/services/metrics_service.dart';
import '../../services/settings_service.dart';
import '../../services/work_timer_service.dart';
import '../../widgets/ping_indicator.dart';
import '../../widgets/role_badge.dart';
import '../../services/app_store.dart';
import '../../widgets/metric_chart.dart';
import '../notes/note_editor_screen.dart';
import '../snippets/snippet_editor_screen.dart';

/// Экран дашборда: сводка задач, заметок, сниппетов, таймер, графики.
class DashboardScreen extends StatefulWidget {
  final void Function(int index)? onGoToTab;
  const DashboardScreen({super.key, this.onGoToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _inProgress = 0;
  int _doneCount = 0;
  int _totalTasks = 0;
  int _doneToday = 0;
  int _totalNotes = 0;
  int _totalSnippets = 0;
  bool _prevRunning = false;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _load();
    }
  }

  Future<void> _load() async {
    final store = context.read<AppStore>();
    final taskService = context.read<TaskService>();
    final metricsService = context.read<MetricsService>();

    final tasks = await taskService.getAllTasks();
    final notes = await taskService.getAllNotes();
    final snippets = await taskService.getAllSnippets();
    final taskStats = await metricsService.getTaskStats();
    final doneToday = await metricsService.getTaskCompletedToday();

    await store.refreshMetrics();

    if (!mounted) return;
    setState(() {
      _inProgress = taskStats['in_progress'] ?? 0;
      _doneCount = taskStats['done'] ?? 0;
      _totalTasks = tasks.length;
      _doneToday = doneToday;
      _totalNotes = notes.length;
      _totalSnippets = snippets.length;
    });
  }

  String _username() => context.read<SettingsService>().username;

  Future<void> _createTask() async {
    final result = await _showTaskDialog(context);
    if (result != null && context.mounted) {
      await context.read<TaskService>().createTask(Task(
        title: result['title']!,
        description: result['description'],
        commitHash: result['commitHash'],
      ));
      _load();
    }
  }

  Future<void> _createNote() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
    );
    _load();
  }

  Future<void> _createSnippet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SnippetEditorScreen()),
    );
    _load();
  }

  Future<void> _openIde() async {
    final settings = context.read<SettingsService>();
    final cmd = settings.ideCommand;
    try {
      final parts = cmd.split(' ');
      await Process.start(parts.first, [
        ...parts.sublist(1),
        '/home/venturn/Рабочий стол/companion',
      ]);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось запустить $cmd')),
      );
    }
  }

  Future<void> _addManualTime() async {
    final taskService = context.read<TaskService>();
    final tasks = await taskService.getAllTasks();
    final now = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        DateTime startDate = now;
        DateTime endDate = now;
        String? taskId;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Добавить время вручную'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tasks.isNotEmpty)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Задача (необяз.)',
                      ),
                      items: tasks
                          .map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text('${t.taskNumber} ${t.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => taskId = v),
                    ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text('Начало: ${DateFormat('HH:mm dd.MM', 'ru').format(startDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: startDate.subtract(const Duration(days: 30)),
                        lastDate: now,
                      );
                      if (picked == null) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(startDate),
                      );
                      if (time == null) return;
                      setDialogState(() {
                        startDate = DateTime(
                          picked.year, picked.month, picked.day,
                          time.hour, time.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text('Конец: ${DateFormat('HH:mm dd.MM', 'ru').format(endDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate,
                        firstDate: endDate.subtract(const Duration(days: 30)),
                        lastDate: now.add(const Duration(days: 1)),
                      );
                      if (picked == null) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(endDate),
                      );
                      if (time == null) return;
                      setDialogState(() {
                        endDate = DateTime(
                          picked.year, picked.month, picked.day,
                          time.hour, time.minute,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  if (endDate.isBefore(startDate)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Конец раньше начала')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, {
                    'taskId': taskId,
                    'startTime': startDate,
                    'endTime': endDate,
                  });
                },
                child: const Text('Добавить'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    final session = WorkSession(
      startTime: result['startTime'] as DateTime,
      endTime: result['endTime'] as DateTime,
      taskId: result['taskId'] as String?,
    );
    session.durationSeconds =
        session.endTime!.difference(session.startTime).inSeconds;
    await context.read<MetricsService>().addManualTime(session);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateStr = DateFormat('d MMMM yyyy, EEEE', 'ru').format(now);
    final timer = context.watch<WorkTimerService>();
    final store = context.watch<AppStore>();

    if (_prevRunning && !timer.isRunning) _load();
    _prevRunning = timer.isRunning;

    int displaySeconds = store.todayWorkSeconds;
    if (timer.isRunning) displaySeconds += timer.elapsed.inSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дашборд'),
        actions: const [PingIndicator(), RoleBadge()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Добро пожаловать, ${_username()}!',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(dateStr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 20),
            _progressBar(theme, 'В работе', _inProgress, _totalTasks, Colors.orange),
            _progressBar(theme, 'Готово', _doneCount, _totalTasks, Colors.green),
            _statCard(theme, 'Завершено сегодня', _doneToday,
                Icons.check_circle, Colors.green),
            _statCard(theme, 'Заметок', _totalNotes, Icons.note, Colors.blue),
            _statCard(theme, 'Сниппетов', _totalSnippets, Icons.code, Colors.purple),
            const SizedBox(height: 8),
            _timerCard(theme, timer, displaySeconds),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Время работы за неделю',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    MetricChart(
                      dailyCounts: store.weeklyWork,
                      color: theme.colorScheme.primary,
                      showStats: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openIde,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Открыть IDE'),
                  ),
                ),
                if (store.userRole != 'reader') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addManualTime,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Время вручную'),
                    ),
                  ),
                ],
              ],
            ),
            if (store.userRole != 'reader') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _createTask,
                      icon: const Icon(Icons.add_task),
                      label: const Text('Создать задачу'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _createNote,
                      icon: const Icon(Icons.note_add),
                      label: const Text('Новая заметка'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _createSnippet,
                  icon: const Icon(Icons.code),
                  label: const Text('Добавить сниппет'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _progressBar(
      ThemeData theme, String label, int value, int? total, Color color) {
    final ratio = (total != null && total > 0) ? value / total : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: total != null ? ratio : null,
                      backgroundColor: color.withValues(alpha: 0.15),
                      color: color,
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  total != null ? '$value/$total' : '$value',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      ThemeData theme, String label, int count, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        trailing: Text('$count',
            style: theme.textTheme.headlineSmall?.copyWith(color: color)),
      ),
    );
  }

  Widget _timerCard(ThemeData theme, WorkTimerService timer, int displaySeconds) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timer,
                    color: timer.isRunning ? Colors.green : Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timer.isRunning ? 'В работе' : 'Не работаете',
                          style: theme.textTheme.bodyMedium),
                      if (timer.isRunning)
                        Text(timer.elapsedFormatted,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Сегодня отработано',
                    style: theme.textTheme.bodySmall),
                const Spacer(),
                Text(_formatDuration(displaySeconds),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// TODO: перенести в отдельный widget-файл
Future<Map<String, String?>?> _showTaskDialog(
  BuildContext context, {
  Task? task,
}) {
  final titleCtrl = TextEditingController(text: task?.title ?? '');
  final descCtrl = TextEditingController(text: task?.description ?? '');
  final hashCtrl = TextEditingController(text: task?.commitHash ?? '');

  return showDialog<Map<String, String?>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(task == null ? 'Новая задача' : 'Редактировать'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Заголовок'),
          ),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Описание'),
            maxLines: 3,
          ),
          TextField(
            controller: hashCtrl,
            decoration: const InputDecoration(labelText: 'Commit hash'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, {
            'title': titleCtrl.text,
            'description': descCtrl.text.isEmpty ? null : descCtrl.text,
            'commitHash': hashCtrl.text.isEmpty ? null : hashCtrl.text,
          }),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

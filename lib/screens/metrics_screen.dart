import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../services/work_timer_service.dart';
import '../services/app_store.dart';
import '../widgets/metric_chart.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final _repo = ActivityRepository();
  List<Activity> _activities = [];
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
    final activities = await _repo.getAll();
    await store.refreshMetrics();
    if (!mounted) return;
    setState(() => _activities = activities);
  }

  int _count(ActivityType type) =>
      _activities.where((a) => a.type == type).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = context.watch<WorkTimerService>();
    final store = context.watch<AppStore>();

    if (_prevRunning && !timer.isRunning) {
      _load();
    }
    _prevRunning = timer.isRunning;

    int displaySeconds = store.todayWorkSeconds;
    if (timer.isRunning) {
      displaySeconds += timer.elapsed.inSeconds;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Метрики')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(theme, 'Создано задач', _count(ActivityType.taskCreated),
                Icons.add_task, Colors.blue),
            _card(theme, 'Завершено задач',
                _count(ActivityType.taskCompleted), Icons.check_circle, Colors.green),
            _card(theme, 'Заметок', _count(ActivityType.noteCreated),
                Icons.note, Colors.orange),
            _card(theme, 'Сниппетов', _count(ActivityType.snippetCreated),
                Icons.code, Colors.purple),
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.timer, color: Colors.green),
                title: const Text('Время работы сегодня'),
                trailing: Text(_formatDuration(displaySeconds),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: Colors.green)),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Активность за 14 дней',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    MetricChart(
                      dailyCounts: store.dailyActivityCounts,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                        color: Colors.green,
                      ),
                  ],
                ),
              ),
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

  Widget _card(ThemeData theme, String label, int count, IconData icon, Color color) {
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
}

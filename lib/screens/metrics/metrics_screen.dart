import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity.dart';
import '../../domain/services/metrics_service.dart';
import '../../services/work_timer_service.dart';
import '../../services/app_store.dart';
import '../../widgets/metric_chart.dart';

/// Экран метрик: статистика активностей, время работы, графики.
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  Map<ActivityType, int> _counts = {};
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
    final metricsService = context.read<MetricsService>();
    final counts = await metricsService.getActivityTypeCounts();
    final store = context.read<AppStore>();
    await store.refreshMetrics();
    if (!mounted) return;
    setState(() => _counts = counts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = context.watch<WorkTimerService>();
    final store = context.watch<AppStore>();

    if (_prevRunning && !timer.isRunning) _load();
    _prevRunning = timer.isRunning;

    int displaySeconds = store.todayWorkSeconds;
    if (timer.isRunning) displaySeconds += timer.elapsed.inSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Метрики')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(theme, 'Создано задач',
                _counts[ActivityType.taskCreated] ?? 0,
                Icons.add_task, Colors.blue),
            _card(theme, 'Завершено задач',
                _counts[ActivityType.taskCompleted] ?? 0,
                Icons.check_circle, Colors.green),
            _card(theme, 'Заметок',
                _counts[ActivityType.noteCreated] ?? 0,
                Icons.note, Colors.orange),
            _card(theme, 'Сниппетов',
                _counts[ActivityType.snippetCreated] ?? 0,
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

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

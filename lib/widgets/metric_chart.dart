import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MetricChart extends StatelessWidget {
  final Map<DateTime, int> dailyCounts;
  final Color color;
  final bool showStats;

  const MetricChart({
    super.key,
    required this.dailyCounts,
    this.color = Colors.indigo,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = dailyCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (sorted.isEmpty) {
      return const SizedBox(
          height: 120, child: Center(child: Text('Нет данных')));
    }

    final maxVal = sorted.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);
    final avg = (total / sorted.length).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sorted.length) {
                        return const SizedBox();
                      }
                      final date = sorted[idx].key;
                      final dayStr = DateFormat('E', 'ru').format(date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(dayStr.substring(0, 2),
                            style: const TextStyle(fontSize: 9)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final idx = group.x;
                    if (idx < 0 || idx >= sorted.length) return null;
                    final entry = sorted[idx];
                    final dateStr =
                        DateFormat('d MMM', 'ru').format(entry.key);
                    return BarTooltipItem(
                      '$dateStr\n${entry.value}',
                      TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              barGroups: sorted.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.value.toDouble(),
                      color: color.withValues(
                        alpha: maxVal > 0
                            ? 0.3 + 0.7 * (e.value.value / maxVal)
                            : 0.5,
                      ),
                      width: 12,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        if (showStats)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _statChip(context, 'Итого', '$total'),
                const SizedBox(width: 12),
                _statChip(context, 'Среднее', avg),
                const SizedBox(width: 12),
                _statChip(context, 'Макс', '$maxVal'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: theme.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w500)),
    );
  }
}

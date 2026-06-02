import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ping_service.dart';
import '../services/app_store.dart';

/// Индикатор качества сети: иконка + пинг в мс.
class PingIndicator extends StatelessWidget {
  const PingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.isConnected) return const SizedBox.shrink();

    return Consumer<PingService>(
      builder: (context, ping, child) {
        final p = ping.currentPing;
        if (p == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.signal_wifi_off, color: Colors.grey, size: 16),
          );
        }

        Color color;
        if (p < 50) {
          color = Colors.green;
        } else if (p < 100) {
          color = Colors.amber;
        } else if (p < 200) {
          color = Colors.orange;
        } else {
          color = Colors.red;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.signal_wifi_4_bar, color: color, size: 14),
              const SizedBox(width: 4),
              Text('$p мс', style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}

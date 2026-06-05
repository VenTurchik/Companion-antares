import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key});

  static const Map<String, String> _labels = {
    'root': 'Владелец',
    'admin': 'Администратор',
    'participant': 'Участник',
    'reader': 'Читатель',
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final role = store.userRole;
    if (role == null || !store.isConnected) return const SizedBox.shrink();

    Color color;
    switch (role) {
      case 'root':
        color = Colors.red;
      case 'admin':
        color = Colors.orange;
      case 'participant':
        color = Colors.blue;
      default:
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(_labels[role] ?? role,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

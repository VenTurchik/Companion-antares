import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class UserNameBadge extends StatelessWidget {
  const UserNameBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final name = store.userName?.trim();
    final display = (name != null && name.isNotEmpty) ? name : 'Antares';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(display,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../database/database_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Тема', style: theme.textTheme.titleMedium),
          ...ThemeMode.values.map((mode) => RadioListTile<ThemeMode>(
            // ignore: deprecated_member_use
            title: Text(_themeLabel(mode)),
            value: mode,
            // ignore: deprecated_member_use
            groupValue: settings.themeMode,
            // ignore: deprecated_member_use
            onChanged: (v) => settings.setThemeMode(v!),
          )),
          const Divider(),
          TextField(
            decoration:
                const InputDecoration(labelText: 'Имя пользователя'),
            controller: TextEditingController.fromValue(
              TextEditingValue(text: settings.username),
            ),
            onSubmitted: (v) => settings.setUsername(v),
          ),
          const Divider(),
          Text('Язык подсветки по умолчанию',
              style: theme.textTheme.titleMedium),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: settings.defaultLanguage,
            items: [
              'dart',
              'python',
              'javascript',
              'bash',
              'cpp',
              'java',
              'rust',
              'go',
              'sql',
              'yaml',
              'json',
              'html',
              'css',
            ]
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => settings.setDefaultLanguage(v!),
          ),
          const Divider(),
          Text('IDE для открытия проектов',
              style: theme.textTheme.titleMedium),
          ...settings.availableIdeOptions.map((opt) => RadioListTile<String>(
            title: Text(opt.label),
            subtitle: Text(opt.primaryCommand),
            value: opt.primaryCommand,
            groupValue: settings.ideCommand,
            onChanged: (v) => settings.setIdeCommand(v!),
          )),
          const Divider(),
          FilledButton.tonalIcon(
            onPressed: () => _reset(context, settings),
            icon: const Icon(Icons.restore),
            label: const Text('Сбросить всё'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _about(context),
            icon: const Icon(Icons.info_outline),
            label: const Text('О приложении'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.dark:
        return 'Тёмная';
      case ThemeMode.system:
        return 'Системная';
    }
  }

  Future<void> _reset(BuildContext context, SettingsService settings) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить всё'),
        content: const Text('Все данные будут удалены. Вы уверены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final db = DatabaseHelper();
      await db.db.delete('tasks');
      await db.db.delete('notes');
      await db.db.delete('snippets');
      await db.db.delete('activities');
      await settings.resetAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Все данные сброшены')),
        );
      }
    }
  }

  void _about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Companion',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Личное рабочее пространство разработчика',
    );
  }
}

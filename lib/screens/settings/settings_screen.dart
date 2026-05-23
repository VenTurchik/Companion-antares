import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';

/// Экран настроек: тема, имя, язык, IDE, сброс, управление колонками.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Тема ----
          _section(theme, 'Тема'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Светлая'),
                    value: ThemeMode.light,
                    groupValue: settings.themeMode,
                    onChanged: (v) => settings.setThemeMode(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Тёмная'),
                    value: ThemeMode.dark,
                    groupValue: settings.themeMode,
                    onChanged: (v) => settings.setThemeMode(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Системная'),
                    value: ThemeMode.system,
                    groupValue: settings.themeMode,
                    onChanged: (v) => settings.setThemeMode(v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Пользователь ----
          _section(theme, 'Пользователь'),
          Card(
            child: ListTile(
              title: TextField(
                decoration: const InputDecoration(labelText: 'Имя'),
                controller: TextEditingController(text: settings.username),
                onSubmitted: (v) => settings.setUsername(v),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Язык сниппетов ----
          _section(theme, 'Язык сниппетов по умолчанию'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                initialValue: settings.defaultLanguage,
                items: ['dart', 'python', 'javascript', 'typescript', 'go',
                    'rust', 'cpp', 'java', 'kotlin', 'swift', 'yaml', 'json',
                    'shell', 'sql', 'html', 'css']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => settings.setDefaultLanguage(v!),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- IDE ----
          _section(theme, 'Редактор кода'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ...settings.availableIdeOptions.map((ide) => RadioListTile<String>(
                    title: Text(ide.label),
                    value: ide.primaryCommand,
                    groupValue: settings.ideCommand,
                    onChanged: (v) => settings.setIdeCommand(v!),
                    subtitle: ide.available ? null
                        : const Text('не найден', style: TextStyle(color: Colors.red)),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Сброс ----
          _section(theme, 'Сброс'),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Сбросить настройки?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Отмена')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Сбросить')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await settings.resetAll();
                }
              },
              icon: const Icon(Icons.restore),
              label: const Text('Сбросить все настройки'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_store.dart';
import '../../services/network_adapter.dart';
import '../../services/loading_service.dart';
import '../../widgets/role_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loader = context.read<LoadingService>();
    loader.startLoading('Загрузка профиля...');
    setState(() => _loading = true);
    try {
      final adapter = context.read<AntaresNetworkAdapter>();
      final profile = await adapter.getUserProfile();
      if (!mounted) return;
      setState(() {
        _loading = false;
        final userName = profile?['name']?.toString() ??
            profile?['username']?.toString() ??
            context.read<AppStore>().userName ?? '';
        _nameCtrl.text = userName;
      });
    } finally {
      loader.stopLoading();
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final loader = context.read<LoadingService>();
    loader.startLoading('Сохранение...');
    setState(() => _saving = true);
    try {
      final ok =
          await context.read<AntaresNetworkAdapter>().updateUserProfile(name);
      if (!mounted) return;
      if (ok) {
        try {
          await context.read<AppStore>().setUserName(name);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка сохранения имени локально: $e'),
                  backgroundColor: Colors.red),
            );
          }
        }
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Имя сохранено' : 'Ошибка сохранения'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      if (ok) _load();
    } finally {
      loader.stopLoading();
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'root':
        return Colors.red;
      case 'admin':
        return Colors.orange;
      case 'participant':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'root':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'participant':
        return 'Участник';
      default:
        return 'Читатель';
    }
  }

  String _platformName() {
    final os = Platform.operatingSystem;
    if (os == 'windows') return 'Windows';
    if (os == 'linux') return 'Linux';
    if (os == 'macos') return 'macOS';
    return os;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final adapter = context.watch<AntaresNetworkAdapter>();
    final connected = adapter.isConnected;
    final role = store.userRole ?? 'reader';
    final color = _roleColor(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой профиль'),
        actions: const [RoleBadge()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Text(
                          _nameCtrl.text.isNotEmpty
                              ? _nameCtrl.text[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontSize: 32,
                              color: color,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (connected) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(_roleLabel(role),
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Имя пользователя',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Введите имя',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Сохранить'),
                            ),
                          ],
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
                      children: [
                        if (connected) ...[
                          _infoRow(theme, Icons.badge, 'Роль',
                              _roleLabel(role)),
                          const Divider(),
                          _infoRow(theme, Icons.desktop_mac, 'Платформа',
                              'Antares · ${_platformName()}'),
                          const Divider(),
                          _infoRow(
                              theme, Icons.info, 'Версия', '0.1.0'),
                          const Divider(),
                          _infoRow(theme, Icons.dns, 'Сервер',
                              store.serverUrl ?? '—'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (connected)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await adapter.disconnect();
                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.link_off),
                      label: const Text('Отключиться от сервера'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                if (connected) const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => exit(0),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Выйти из приложения'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

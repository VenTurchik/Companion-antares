import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/app_store.dart';
import '../../services/network_adapter.dart';

/// Экран подключения к серверу POLARIS.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _urlCtrl = TextEditingController();
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    if (store.serverUrl != null) {
      _urlCtrl.text = store.serverUrl!;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите URL сервера')),
      );
      return;
    }
    setState(() => _connecting = true);
    final adapter = context.read<AntaresNetworkAdapter>();
    final ok = await adapter.connect(url);
    if (mounted) {
      setState(() => _connecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Подключено к POLARIS' : 'Ошибка подключения'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final adapter = context.read<AntaresNetworkAdapter>();
    await adapter.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отключено от сервера')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final adapter = context.watch<AntaresNetworkAdapter>();

    return Scaffold(
      appBar: AppBar(title: const Text('Подключение к серверу')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Статус подключения
            _statusCard(theme, store, adapter),
            const SizedBox(height: 24),
            // Поле ввода URL
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL сервера',
                hintText: 'http://192.168.1.100:8080',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
              ),
              enabled: !_connecting && !adapter.isConnected,
            ),
            const SizedBox(height: 16),
            // Кнопка
            SizedBox(
              width: double.infinity,
              height: 48,
              child: adapter.isConnected
                  ? FilledButton.tonalIcon(
                      onPressed: _connecting ? null : _disconnect,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Отключиться'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _connecting ? null : _connect,
                      icon: _connecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: Text(_connecting ? 'Подключение...' : 'Подключиться'),
                    ),
            ),
            const SizedBox(height: 24),
            // Информация о сервере
            if (store.isConnected && store.serverName != null) ...[
              Text('Информация о сервере',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _infoRow(theme, 'Имя', store.serverName!),
              if (store.serverUrl != null)
                _infoRow(theme, 'URL', store.serverUrl!),
              if (store.userRole != null)
                _infoRow(theme, 'Роль', store.userRole!),
              if (store.connectedAt != null)
                _infoRow(theme, 'Подключено',
                    DateFormat('dd.MM.yyyy HH:mm', 'ru').format(store.connectedAt!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusCard(ThemeData theme, AppStore store, AntaresNetworkAdapter adapter) {
    final connected = adapter.isConnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              connected ? Icons.cloud_done : Icons.cloud_off,
              size: 40,
              color: connected ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Подключено' : 'Локальный режим',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (connected && store.serverName != null)
                  Text(store.serverName!,
                      style: theme.textTheme.bodyMedium),
                if (connected && store.userRole != null)
                  Text('Роль: ${store.userRole!}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

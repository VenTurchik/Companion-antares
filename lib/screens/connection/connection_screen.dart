import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/app_store.dart';
import '../../services/network_adapter.dart';
import '../../services/sync_service.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _urlCtrl = TextEditingController();
  bool _connecting = false;
  bool _scanning = false;

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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подключение к серверу'),
        content: const Text('Загрузить данные с сервера? Локальные данные будут заменены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Только подключиться'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Загрузить данные'),
          ),
        ],
      ),
    );

    if (ok == null) return;

    setState(() => _connecting = true);
    final adapter = context.read<AntaresNetworkAdapter>();
    final success = await adapter.connect(url);
    if (mounted) {
      setState(() => _connecting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Подключено к POLARIS'), backgroundColor: Colors.green),
        );
        await adapter.getServerStats();
        if (ok) {
          context.read<SyncService>().copyServerData();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка подключения'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отключение от сервера'),
        content: const Text('Сохранить копию данных сервера локально?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Не сохранять'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сохранить копию'),
          ),
        ],
      ),
    );

    if (ok == null) return;

    if (ok) {
      final syncService = context.read<SyncService>();
      await syncService.copyServerData();
    }

    final adapter = context.read<AntaresNetworkAdapter>();
    await adapter.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отключено от сервера')),
      );
    }
  }

  Future<void> _copyData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Копирование данных'),
        content: const Text('Скопировать все данные с сервера в локальное хранилище?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Копировать'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final syncService = context.read<SyncService>();
    await syncService.copyServerData();
    if (mounted) {
      context.read<AntaresNetworkAdapter>().getServerStats();
    }
  }

  Future<void> _scanNetwork() async {
    setState(() => _scanning = true);
    final servers = await AntaresNetworkAdapter.discover();
    if (mounted) {
      setState(() => _scanning = false);
      if (servers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Серверы не найдены')),
        );
      } else if (servers.length == 1) {
        _urlCtrl.text = servers.first['url'] ?? '';
      } else {
        _showServerPicker(servers);
      }
    }
  }

  void _showServerPicker(List<Map<String, String>> servers) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Найденные серверы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: servers.map((s) => ListTile(
            leading: const Icon(Icons.dns),
            title: Text(s['name'] ?? 'POLARIS'),
            subtitle: Text(s['url'] ?? ''),
            onTap: () {
              _urlCtrl.text = s['url'] ?? '';
              Navigator.of(ctx).pop();
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final adapter = context.watch<AntaresNetworkAdapter>();

    return Scaffold(
      appBar: AppBar(
        title: Text(store.connectionLabel),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusCard(theme, store, adapter),
            const SizedBox(height: 24),
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
            if (!adapter.isConnected)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _scanning ? null : _scanNetwork,
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_scanning ? 'Сканирование...' : 'Сканировать сеть'),
                  ),
                ),
              ),
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
            if (adapter.isConnected) ...[
              Text('Информация о сервере',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _infoRow(theme, 'Имя', store.serverName ?? ''),
              if (store.serverUrl != null)
                _infoRow(theme, 'URL', store.serverUrl!),
              if (store.userRole != null)
                _infoRow(theme, 'Роль', store.userRole!),
              if (store.connectedAt != null)
                _infoRow(theme, 'Подключено',
                    DateFormat('dd.MM.yyyy HH:mm', 'ru').format(store.connectedAt!)),
              const SizedBox(height: 24),
              _copySection(theme, context, store),
              const SizedBox(height: 24),
              if (adapter.serverStats != null)
                _statsSection(theme, adapter),
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
                  connected ? 'Командный режим' : 'Локальный режим',
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

  Widget _copySection(ThemeData theme, BuildContext context, AppStore store) {
    final syncService = context.watch<SyncService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Копирование данных',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (syncService.lastMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(syncService.lastMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: syncService.state == SyncState.error
                      ? Colors.red
                      : syncService.state == SyncState.done
                          ? Colors.green
                          : null,
                )),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.tonalIcon(
            onPressed: syncService.state != SyncState.syncing
                ? _copyData
                : null,
            icon: syncService.state == SyncState.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            label: Text(
              syncService.state == SyncState.syncing
                  ? 'Копирование...'
                  : 'Скопировать данные сервера'),
          ),
        ),
        if (syncService.state == SyncState.done && store.lastSyncAt != null) ...[
          const SizedBox(height: 4),
          Text('Последняя синхронизация: ${DateFormat('dd.MM.yyyy HH:mm', 'ru').format(store.lastSyncAt!)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _statsSection(ThemeData theme, AntaresNetworkAdapter adapter) {
    final stats = adapter.serverStats;
    if (stats == null) return const SizedBox.shrink();

    final diskFree = _fmtBytes(stats['disk_free_gb']);
    final diskTotal = _fmtBytes(stats['disk_total_gb']);
    final dbSize = _fmtBytes(stats['db_size_mb'], unit: 'MB');
    final kbSize = _fmtBytes(stats['knowledge_base_size_mb'], unit: 'MB');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Статистика сервера',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow(Icons.storage, 'Диск', '$diskFree / $diskTotal GB'),
                const SizedBox(height: 4),
                _statRow(Icons.dns, 'БД', '$dbSize | База знаний: $kbSize'),
                const SizedBox(height: 4),
                _statRow(Icons.people, 'Пользователей',
                    '${stats['users_count'] ?? 0}'),
                const SizedBox(height: 4),
                _statRow(Icons.assignment, 'Задачи',
                    '${stats['tasks_count'] ?? 0} | Заметок: ${stats['notes_count'] ?? 0} | Сниппетов: ${stats['snippets_count'] ?? 0}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtBytes(dynamic value, {String unit = 'GB'}) {
    if (value == null) return '0.0';
    final v = double.tryParse(value.toString()) ?? 0.0;
    return v.toStringAsFixed(1);
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

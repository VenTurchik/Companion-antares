import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/app_store.dart';
import '../../services/network_adapter.dart';
import '../../services/loading_service.dart';
import '../../services/local_network_discovery.dart';
import '../../services/ping_service.dart';
import '../../widgets/role_badge.dart';


class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _urlCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _connecting = false;
  bool _scanning = false;
  bool _saving = false;
  bool _loadingMembers = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _inviteCodes = [];
  List<Map<String, dynamic>> _archivedInviteCodes = [];
  String? _currentUserId;
  bool _inviting = false;
  String? _selectedCliCommand;
  String? _cliParamValue;
  String _cliOutput = '';
  bool _cliLoading = false;

  static const _cliCommands = [
    _CliCommand('Список приглашений', 'invitations list'),
    _CliCommand('Список пользователей', 'users list'),
    _CliCommand('Статус сервера', 'status'),
    _CliCommand('Список известных устройств', 'known-users list'),
    _CliCommand('Показать root-ключ', 'show-root-key'),
    _CliCommand('Сменить root-ключ', 'change-root-key'),
    _CliCommand('Создать приглашение', 'invite --expires',
        paramLabel: 'Срок действия',
        paramOptions: [
          _CliParamOption('1 день', '1d'),
          _CliParamOption('7 дней', '7d'),
          _CliParamOption('30 дней', '30d'),
          _CliParamOption('навсегда', '0'),
        ]),
    _CliCommand('Перезапустить сервер', 'restart'),
  ];

  _CliCommand? get _selectedCliCmd =>
      _cliCommands.where((c) => c.label == _selectedCliCommand).firstOrNull;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    if (store.serverUrl != null) {
      _urlCtrl.text = store.serverUrl!;
    }
    if (store.userName != null) {
      _nameCtrl.text = store.userName!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      if (context.read<AntaresNetworkAdapter>().isConnected) {
        _loadMembers();
      }
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _selectServer(String url) {
    _urlCtrl.text = url;
    final store = context.read<AppStore>();
    final savedCode = store.getServerToken(url);
    if (savedCode != null) {
      _codeCtrl.text = savedCode;
    }
  }

  Future<void> _loadProfile() async {
    final store = context.read<AppStore>();
    final adapter = context.read<AntaresNetworkAdapter>();
    if (adapter.isConnected) {
      final profile = await adapter.getUserProfile();
      if (mounted) {
        final userName = profile?['name']?.toString() ??
            profile?['username']?.toString() ??
            store.userName ?? '';
        _nameCtrl.text = userName;
      }
    }
  }

  Future<void> _loadMembers() async {
    final adapter = context.read<AntaresNetworkAdapter>();
    final users = await adapter.getUsers();
    final invites = await adapter.getInviteCodes();
    final archived = await adapter.getArchivedInviteCodes();
    final profile = await adapter.getUserProfile();
    if (mounted) {
      setState(() {
        final raw = users ?? [];
        _users = raw.where((u) => u['platform'] != 'CLI').toList();
        _inviteCodes = invites ?? [];
        _archivedInviteCodes = archived ?? [];
        _currentUserId = profile?['id']?.toString();
        _loadingMembers = false;
      });
    }
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите URL сервера')),
      );
      return;
    }
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите код доступа к серверу')),
      );
      return;
    }
    setState(() => _connecting = true);
    final adapter = context.read<AntaresNetworkAdapter>();
    final success = await adapter.connect(url, code);
    if (mounted) {
      setState(() => _connecting = false);
      if (success) {
        _loadProfile();
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Подключено'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка подключения'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final loader = context.read<LoadingService>();
    loader.startLoading('Сохранение...');
    setState(() => _saving = true);
    try {
      final adapter = context.read<AntaresNetworkAdapter>();
      if (adapter.isConnected) {
        final ok = await adapter.updateUserProfile(name);
        if (!mounted) return;
        if (ok) {
          await context.read<AppStore>().setUserName(name);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Имя сохранено' : 'Ошибка сохранения'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      } else {
        await context.read<AppStore>().setUserName(name);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Имя сохранено локально'), backgroundColor: Colors.green),
        );
      }
    } finally {
      loader.stopLoading();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    final adapter = context.read<AntaresNetworkAdapter>();
    final ok = await adapter.changeUserRole(userId, newRole);
    if (!mounted) return;
    if (ok) {
      _loadMembers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка изменения роли'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createInvite() async {
    final loader = context.read<LoadingService>();
    loader.startLoading('Загрузка приглашений...');
    setState(() => _inviting = true);
    try {
      final result = await context.read<AntaresNetworkAdapter>().createInviteCode();
      if (!mounted) return;
      setState(() => _inviting = false);
      if (result != null) {
        final code = result['code']?.toString() ?? 'Ошибка';
        _loadMembers();
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Код приглашения'),
              content: SelectableText(code,
                  style: const TextStyle(fontSize: 24, letterSpacing: 3)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Закрыть')),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка создания приглашения'), backgroundColor: Colors.red),
        );
      }
    } finally {
      loader.stopLoading();
    }
  }

  Future<void> _resetServerDb() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс БД сервера'),
        content: const Text('Вы уверены? Это удалит ВСЕ данные на сервере.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final adapter = context.read<AntaresNetworkAdapter>();
    final success = await adapter.resetServerDb();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'БД сервера сброшена' : 'Ошибка сброса БД'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final adapter = context.watch<AntaresNetworkAdapter>();
    final discovery = context.watch<LocalNetworkDiscovery>();
    final connected = adapter.isConnected;
    final isAdmin = store.userRole == 'root';
    final isRoot = store.userRole == 'root';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подключение'),
        actions: const [RoleBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusCard(theme, store, adapter),
            const SizedBox(height: 24),
            if (!connected) ...[
              _sectionHeader(theme, 'Подключение'),
              const SizedBox(height: 8),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL сервера',
                  hintText: 'http://192.168.1.100:8080',
                  prefixIcon: Icon(Icons.dns),
                  border: OutlineInputBorder(),
                ),
                enabled: !_connecting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Код доступа к серверу',
                  hintText: 'Введите код',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                enabled: !_connecting,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _connecting ? null : _connect,
                  icon: _connecting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(_connecting ? 'Подключение...' : 'Подключиться'),
                ),
              ),
              const SizedBox(height: 24),
              if (store.recentServers.isNotEmpty) ...[
                _sectionHeader(theme, 'Недавние серверы'),
                const SizedBox(height: 8),
                ...store.recentServers.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.dns, size: 20),
                    title: Text(s['name'] ?? s['url'] ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['url'] ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                        if ((s['lastConnected'] ?? '').isNotEmpty)
                          Text(_formatLastSeen(s['lastConnected']!),
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _connecting ? null : () => _connectToServer(s),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(80, 36)),
                      child: const Text('Подкл.'),
                    ),
                  ),
                )),
                const SizedBox(height: 24),
              ],
              _sectionHeader(theme, 'Локальная сеть'),
              const SizedBox(height: 8),
              _discoveredDevicesSection(theme, discovery),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _scanning ? null : _scanNetwork,
                  icon: _scanning
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find),
                  label: Text(_scanning ? 'Сканирование...' : 'Сканировать сеть'),
                ),
              ),
              const SizedBox(height: 24),
            ],
            _sectionHeader(theme, 'Профиль'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Имя пользователя',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saving ? null : _saveName,
                          child: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Сохранить'),
                        ),
                      ],
                    ),
                    if (connected && store.userRole != null) ...[
                      const Divider(),
                      _infoRow(theme, Icons.badge, 'Роль', _roleLabel(store.userRole!)),
                      const Divider(),
                      _infoRow(theme, Icons.desktop_mac, 'Платформа',
                          'Antares · ${Platform.operatingSystem}'),
                    ],
                  ],
                ),
              ),
            ),
            if (connected && store.serverName != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _infoRow(theme, Icons.dns, 'Сервер', store.serverName!),
                      if (store.serverUrl != null) ...[
                        const Divider(),
                        _infoRow(theme, Icons.link, 'URL', store.serverUrl!),
                      ],
                      if (store.connectedAt != null) ...[
                        const Divider(),
                        _infoRow(theme, Icons.access_time, 'Подключено',
                            '${store.connectedAt!.hour}:${store.connectedAt!.minute.toString().padLeft(2, '0')}'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (connected) ...[
              const SizedBox(height: 16),
              _pingSection(theme),
              if (adapter.serverStats != null) ...[
                const SizedBox(height: 16),
                _statsSection(theme, adapter),
              ],
              if (isRoot) ...[
                const SizedBox(height: 24),
                _sectionHeader(theme, 'Управление сервером'),
                const SizedBox(height: 8),
                _buildInviteSection(theme),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
                    onPressed: _resetServerDb,
                    icon: const Icon(Icons.warning_amber),
                    label: const Text('Сбросить БД сервера'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _restartServer,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Перезапустить сервер'),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCliConsole(theme),
              ],
              const SizedBox(height: 24),
              if (isAdmin) ...[
                _sectionHeader(theme, 'Участники'),
                const SizedBox(height: 8),
                _membersSection(theme, store),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Отключиться'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => exit(0),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Выйти из приложения'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Text(title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold));
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
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (connected && store.serverName != null)
                  Text(store.serverName!, style: theme.textTheme.bodyMedium),
                if (connected && store.userRole != null)
                  Text('Роль: ${_roleLabel(store.userRole!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _discoveredDevicesSection(ThemeData theme, LocalNetworkDiscovery discovery) {
    final devices = discovery.devices;
    final servers = discovery.servers;
    final isSearching = discovery.isSearching;

    if (isSearching) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Поиск серверов в локальной сети...', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (servers.isEmpty && devices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (servers.isNotEmpty) ...[
          ...servers.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.dns, size: 20, color: Colors.indigo),
              title: Text(s['name']?.toString() ?? 'POLARIS',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              subtitle: Text(
                '${s['version'] ?? ''} · ${s['url'] ?? ''}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: FilledButton.tonal(
                onPressed: () {
                  _selectServer(s['url']?.toString() ?? '');
                  _connect();
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(80, 36)),
                child: const Text('Подкл.'),
              ),
            ),
          )),
          const SizedBox(height: 12),
        ],
        if (devices.isNotEmpty) ...[
          Text('Клиенты Antares',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...devices.map((d) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.devices, size: 20),
              title: Text(d.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              subtitle: Text(
                '${d.platform} · ${d.ip}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: FilledButton.tonal(
                onPressed: () {
                  _selectServer('http://${d.ip}:8000');
                  _connect();
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(80, 36)),
                child: const Text('Подкл.'),
              ),
            ),
          )),
        ],
      ],
    );
  }

  Widget _membersSection(ThemeData theme, AppStore store) {
    final isRoot = store.userRole == 'root';

    if (_loadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        ..._users.map((u) => _buildUserTile(theme, u, isRoot)),
      ],
    );
  }

  bool _canChangeRole(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';
    if (role == 'root') return false;
    if (userId == _currentUserId) return false;
    return true;
  }

  Widget _buildUserTile(ThemeData theme, Map<String, dynamic> user, bool isRoot) {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name']?.toString() ?? user['username']?.toString() ?? '?';
    final role = user['role']?.toString() ?? 'reader';
    final platform = user['platform']?.toString();
    final lastIp = isRoot ? user['last_ip']?.toString() : null;
    final canChange = isRoot && _canChangeRole(user);
    final color = _roleColor(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _avatarBg(theme, color),
          child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canChange)
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'reader', child: Text('Читатель')),
                  DropdownMenuItem(value: 'participant', child: Text('Участник')),
                  DropdownMenuItem(value: 'admin', child: Text('Модератор')),
                ],
                onChanged: (v) {
                  if (v != null && v != role) _changeRole(userId, v);
                },
                isDense: true,
                decoration: const InputDecoration(
                    border: InputBorder.none, contentPadding: EdgeInsets.zero),
              )
            else
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(_roleLabel(role),
                      style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            if (platform != null || lastIp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    _platformLabel(platform),
                    if (lastIp != null) 'IP: $lastIp',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final active = _inviteCodes.where((i) => i['used_at'] == null).toList();
    final used = _inviteCodes.where((i) => i['used_at'] != null).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Приглашения', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (active.isEmpty && used.isEmpty && _archivedInviteCodes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Нет приглашений',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ),
            ...active.map((inv) => _buildActiveTile(theme, inv)),
            if (used.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(),
              ),
              ...used.map((inv) => _buildUsedTile(theme, inv, isDark)),
            ],
            if (_archivedInviteCodes.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildArchivedSection(theme, isDark),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _inviting ? null : _createInvite,
                icon: _inviting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person_add),
                label: Text(_inviting ? 'Создание...' : 'Пригласить участника'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTile(ThemeData theme, Map<String, dynamic> inv) {
    final code = inv['code']?.toString() ?? '';
    final createdAt = DateTime.tryParse(inv['created_at']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(inv['expires_at']?.toString() ?? '');
    final dateFormat = DateFormat('dd.MM.yy HH:mm');
    final lifetime = expiresAt != null
        ? 'до ${dateFormat.format(expiresAt)}'
        : createdAt != null
            ? 'создано ${dateFormat.format(createdAt)}'
            : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.link, color: Colors.green, size: 20),
        title: Text(code,
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        subtitle: Text('Активно${lifetime.isNotEmpty ? ' · $lifetime' : ''}',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Код скопирован')),
                );
              },
              tooltip: 'Копировать',
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              color: Colors.red,
              onPressed: () => _revokeInvite(code),
              tooltip: 'Отозвать',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsedTile(ThemeData theme, Map<String, dynamic> inv, bool isDark) {
    final code = inv['code']?.toString() ?? '';
    final usedDt = DateTime.tryParse(inv['used_at']?.toString() ?? '');
    final usedBy = inv['used_by']?.toString();
    final dateFormat = DateFormat('dd.MM.yy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle_outline, color: Colors.grey, size: 20),
        title: Text(code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            )),
        subtitle: Text(
          usedDt != null
              ? 'Использовано ${dateFormat.format(usedDt)}${usedBy != null ? ' · $usedBy' : ''}'
              : 'Использовано',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: Colors.grey,
          onPressed: () => _deleteInvite(code),
          tooltip: 'Удалить',
        ),
      ),
    );
  }

  Widget _buildArchivedSection(ThemeData theme, bool isDark) {
    final dateFormat = DateFormat('dd.MM.yy HH:mm');
    return ExpansionTile(
      title: Text('Архив приглашений (${_archivedInviteCodes.length})'),
      leading: const Icon(Icons.archive_outlined, size: 20),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      children: _archivedInviteCodes.map((inv) {
        final code = inv['code']?.toString() ?? '';
        final usedDt = DateTime.tryParse(inv['used_at']?.toString() ?? '');
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle_outline, color: Colors.grey, size: 20),
            title: Text(code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                )),
            subtitle: Text(
              usedDt != null ? 'Архив · ${dateFormat.format(usedDt)}' : 'Архив',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.grey,
              onPressed: () => _deleteInvite(code),
              tooltip: 'Удалить',
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _revokeInvite(String code) async {
    final ok = await context.read<AntaresNetworkAdapter>().deleteInviteCode(code);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Приглашение отозвано' : 'Ошибка отзыва'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      if (ok) _loadMembers();
    }
  }

  Future<void> _deleteInvite(String code) async {
    final ok = await context.read<AntaresNetworkAdapter>().deleteInviteCode(code);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Приглашение удалено' : 'Ошибка удаления'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      if (ok) _loadMembers();
    }
  }

  Future<void> _restartServer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Перезапустить сервер?'),
        content: const Text('Сервер будет перезапущен. Подключение прервётся.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Перезапустить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await context.read<AntaresNetworkAdapter>().restartServer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Сервер перезапускается' : 'Ошибка перезапуска'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildCliConsole(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final cmd = _selectedCliCmd;
    final hasParam = cmd?.paramOptions?.isNotEmpty ?? false;

    return Card(
      child: ExpansionTile(
        title: const Text('Консоль'),
        leading: const Icon(Icons.terminal, size: 20),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCliCommand,
                  hint: const Text('Выберите команду'),
                  isExpanded: true,
                  items: _cliCommands.map((c) => DropdownMenuItem(
                    value: c.label,
                    child: Text(c.label),
                  )).toList(),
                  onChanged: (v) => setState(() {
                    _selectedCliCommand = v;
                    final newCmd = _cliCommands.where((c) => c.label == v).firstOrNull;
                    _cliParamValue = newCmd?.paramOptions?.firstOrNull?.value;
                  }),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                if (hasParam) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _cliParamValue,
                    hint: Text(cmd!.paramLabel!),
                    isExpanded: true,
                    items: cmd.paramOptions!.map((o) => DropdownMenuItem(
                      value: o.value,
                      child: Text(o.label),
                    )).toList(),
                    onChanged: (v) => setState(() => _cliParamValue = v),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_selectedCliCommand == null || _cliLoading) ? null : _executeCli,
                        icon: _cliLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Выполнить'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _cliOutput.isEmpty ? null : () => setState(() => _cliOutput = ''),
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Очистить'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _cliOutput.isEmpty ? 'Вывод команды...' : _cliOutput,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _cliOutput.startsWith('[ОШИБКА]')
                            ? Colors.red
                            : isDark ? const Color(0xFF00FF00) : const Color(0xFF006600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCli() async {
    final cmd = _selectedCliCmd;
    if (cmd == null) return;
    final param = _cliParamValue;
    final fullCmd = param != null ? '${cmd.command} $param' : cmd.command;
    setState(() {
      _cliLoading = true;
      _cliOutput = '';
    });
    final result = await context.read<AntaresNetworkAdapter>().executeCli(fullCmd);
    if (mounted) {
      setState(() {
        _cliLoading = false;
        final output = result?['output']?.toString() ?? '';
        final error = result?['error']?.toString() ?? '';
        if (output.isNotEmpty) {
          _cliOutput = output;
        } else if (error.isNotEmpty) {
          _cliOutput = '[ОШИБКА] $error';
        } else {
          _cliOutput = 'Команда выполнена.';
        }
      });
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'root': return Colors.red;
      case 'admin': return Colors.orange;
      case 'participant': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'root': return 'Владелец';
      case 'admin': return 'Администратор';
      case 'participant': return 'Участник';
      default: return 'Читатель';
    }
  }

  String _platformLabel(String? platform) {
    if (platform == null) return '';
    switch (platform.toLowerCase()) {
      case 'windows': return 'Windows';
      case 'linux': return 'Linux';
      case 'macos': return 'macOS';
      default: return platform;
    }
  }

  Color _avatarBg(ThemeData theme, Color color) {
    return color.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 0.2);
  }

  Widget _pingSection(ThemeData theme) {
    final ping = context.watch<PingService>();
    if (!context.read<AppStore>().isConnected) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Качество сети',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _pingIcon(ping.currentPing),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ping.currentPing != null) ...[
                        Text('Текущий: ${ping.currentPing} мс', style: theme.textTheme.bodyMedium),
                        Text('Средний: ${ping.averagePing} мс',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        Text('Качество: ${ping.quality ?? "нет связи"}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ] else
                        const Text('Нет связи с сервером'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pingIcon(int? p) {
    if (p == null) {
      return const Icon(Icons.signal_wifi_off, color: Colors.grey, size: 32);
    }
    Color color;
    if (p < 50) { color = Colors.green; }
    else if (p < 100) { color = Colors.amber; }
    else if (p < 200) { color = Colors.orange; }
    else { color = Colors.red; }
    return Icon(Icons.signal_wifi_4_bar, color: color, size: 32);
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
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                _statRow(Icons.people, 'Пользователей', '${stats['users_count'] ?? 0}'),
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

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
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

  Future<void> _scanNetwork() async {
    print('[LAN] Сканирование локальной сети...');
    setState(() => _scanning = true);
    final servers = await AntaresNetworkAdapter.discover();
    if (mounted) {
      setState(() => _scanning = false);
      if (servers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Серверы не найдены')),
        );
      } else if (servers.length == 1) {
        _selectServer(servers.first['url'] ?? '');
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
              _selectServer(s['url'] ?? '');
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

  Future<void> _connectToServer(Map<String, String> server) async {
    final url = server['url'] ?? '';
    if (url.isEmpty) return;
    _selectServer(url);
    await _connect();
  }

  String _formatLastSeen(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) {
      return 'сегодня в ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) {
      return 'вчера в ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

class _CliCommand {
  final String label;
  final String command;
  final String? paramLabel;
  final List<_CliParamOption>? paramOptions;

  const _CliCommand(this.label, this.command, {this.paramLabel, this.paramOptions});
}

class _CliParamOption {
  final String label;
  final String value;
  const _CliParamOption(this.label, this.value);
}

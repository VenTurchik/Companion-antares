import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/app_store.dart';
import '../../services/network_adapter.dart';
import '../../widgets/ping_indicator.dart';
import '../../widgets/role_badge.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Map<String, dynamic>> _users = [];
  String? _inviteCode;
  String? _currentUserId;
  bool _loading = true;
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final adapter = context.read<AntaresNetworkAdapter>();
    final users = await adapter.getUsers();
    final invite = await adapter.getInviteCode();
    final profile = await adapter.getUserProfile();
    if (!mounted) return;
    setState(() {
      final raw = users ?? [];
      _users = raw.where((u) => u['platform'] != 'CLI').toList();
      _inviteCode = invite?['code']?.toString();
      _currentUserId = profile?['id']?.toString();
      _loading = false;
    });
  }

  Future<void> _changeRole(String userId, String newRole) async {
    final adapter = context.read<AntaresNetworkAdapter>();
    final ok = await adapter.changeUserRole(userId, newRole);
    if (!mounted) return;
    if (ok) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ошибка изменения роли'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createInvite() async {
    setState(() => _inviting = true);
    final adapter = context.read<AntaresNetworkAdapter>();
    final result = await adapter.createInviteCode();
    if (!mounted) return;
    setState(() => _inviting = false);
    if (result != null) {
      final code = result['code']?.toString() ?? 'Ошибка';
      setState(() => _inviteCode = code);
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
        const SnackBar(
            content: Text('Ошибка создания приглашения'),
            backgroundColor: Colors.red),
      );
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
        return 'Администратор';
      case 'admin':
        return 'Модератор';
      case 'participant':
        return 'Участник';
      default:
        return 'Читатель';
    }
  }

  String _platformLabel(String? platform) {
    if (platform == null) return '';
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'Windows';
      case 'linux':
        return 'Linux';
      case 'macos':
        return 'macOS';
      default:
        return platform;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final isRoot = store.userRole == 'root';
    final adapter = context.watch<AntaresNetworkAdapter>();
    final connected = adapter.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Участники'),
        actions: const [PingIndicator(), RoleBadge()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !connected
                ? const Center(child: Text('Нет подключения к серверу'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._users
                          .map((u) => _buildUserTile(theme, u, isRoot)),
                      const SizedBox(height: 16),
                      if (isRoot) _buildInviteSection(theme),
                    ],
                  ),
      ),
    );
  }

  bool _canChangeRole(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';
    if (role == 'root') return false;
    if (userId == _currentUserId) return false;
    return true;
  }

  Widget _buildUserTile(
      ThemeData theme, Map<String, dynamic> user, bool isRoot) {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name']?.toString() ??
        user['username']?.toString() ??
        '?';
    final role = user['role']?.toString() ?? 'reader';
    final platform = user['platform']?.toString();
    final lastActive = user['last_active']?.toString();

    final color = _roleColor(role);
    final canChange = isRoot && _canChangeRole(user);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style:
                  TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canChange)
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(
                      value: 'reader', child: Text('Читатель')),
                  DropdownMenuItem(
                      value: 'participant', child: Text('Участник')),
                  DropdownMenuItem(value: 'admin', child: Text('Модератор')),
                ],
                onChanged: (v) {
                  if (v != null && v != role) _changeRole(userId, v);
                },
                isDense: true,
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero),
              )
            else
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(_roleLabel(role),
                      style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            if (platform != null || lastActive != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    _platformLabel(platform),
                    if (lastActive != null) 'активен: $lastActive',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Приглашения', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_inviteCode != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(_inviteCode!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        )),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _inviteCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Код скопирован')),
                      );
                    },
                    tooltip: 'Копировать',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _inviting ? null : _createInvite,
                icon: _inviting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: Text(
                    _inviting ? 'Создание...' : 'Пригласить участника'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

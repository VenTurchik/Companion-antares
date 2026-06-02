import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/snippet.dart';
import '../../domain/services/task_service.dart';
import '../../widgets/ping_indicator.dart';
import '../../widgets/role_badge.dart';
import '../../services/app_store.dart';
import 'snippet_editor_screen.dart';

/// Экран списка сниппетов с поиском и фильтрацией по тегам.
class SnippetListScreen extends StatefulWidget {
  const SnippetListScreen({super.key});

  @override
  State<SnippetListScreen> createState() => _SnippetListScreenState();
}

class _SnippetListScreenState extends State<SnippetListScreen> {
  List<Snippet> _snippets = [];
  List<Snippet> _filtered = [];
  final _searchCtrl = TextEditingController();
  Set<String> _selectedTags = {};
  List<String> _allTags = [];
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snippets = await context.read<TaskService>().getAllSnippets();
    final tags = <String>{};
    for (final s in snippets) {
      tags.addAll(s.tags);
    }
    setState(() {
      _snippets = snippets;
      _allTags = tags.toList()..sort();
      _applyFilter();
    });
  }

  void _applyFilter() {
    var list = _snippets;
    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      list = list.where((s) =>
        s.title.toLowerCase().contains(query) ||
        s.code.toLowerCase().contains(query) ||
        s.language.toLowerCase().contains(query) ||
        s.tags.any((t) => t.toLowerCase().contains(query))
      ).toList();
    }
    if (_selectedTags.isNotEmpty) {
      list = list.where((s) =>
        s.tags.any((t) => _selectedTags.contains(t))
      ).toList();
    }
    setState(() => _filtered = list);
  }

  Future<void> _delete(Snippet snippet) async {
    await context.read<TaskService>().deleteSnippet(snippet.id);
    _load();
  }

  Future<void> _open(Snippet? snippet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SnippetEditorScreen(snippet: snippet)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canCreate = store.userRole != 'reader';
    final canDelete = store.userRole == 'admin' || store.userRole == 'root';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сниппеты'),
        actions: [
          const RoleBadge(),
          const PingIndicator(),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _open(null),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: SearchBar(
                controller: _searchCtrl,
                hintText: 'Поиск...',
                onChanged: (_) => _applyFilter(),
                leading: const Icon(Icons.search),
              ),
            ),
            if (_allTags.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: _allTags.map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      selected: _selectedTags.contains(tag),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                          _applyFilter();
                        });
                      },
                    ),
                  )).toList(),
                ),
              ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('Нет сниппетов'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final snippet = _filtered[index];
                        return ListTile(
                          leading: const Icon(Icons.code),
                          title: Text(snippet.title, maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text('${snippet.language} · ${snippet.tags.join(', ')}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: canDelete
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(snippet),
                                )
                              : null,
                          onTap: () => _open(snippet),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

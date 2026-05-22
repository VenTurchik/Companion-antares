import 'package:flutter/material.dart';
import '../models/snippet.dart';
import '../repositories/snippet_repository.dart';
import 'snippet_editor_screen.dart';

class SnippetListScreen extends StatefulWidget {
  const SnippetListScreen({super.key});

  @override
  State<SnippetListScreen> createState() => _SnippetListScreenState();
}

class _SnippetListScreenState extends State<SnippetListScreen> {
  final _repo = SnippetRepository();
  List<Snippet> _all = [];
  List<Snippet> _filtered = [];
  String _query = '';
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snippets = await _repo.getAll();
    setState(() {
      _all = snippets;
      _applyFilter();
    });
  }

  Set<String> get _allTags {
    final tags = <String>{};
    for (final s in _all) {
      tags.addAll(s.tags);
    }
    return tags;
  }

  void _applyFilter() {
    var list = _all;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) =>
          s.title.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          s.language.toLowerCase().contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }
    if (_selectedTags.isNotEmpty) {
      list = list.where((s) =>
          s.tags.any((t) => _selectedTags.contains(t))).toList();
    }
    _filtered = list;
  }

  Future<void> _open(Snippet? snippet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SnippetEditorScreen(snippet: snippet)),
    );
    _load();
  }

  Future<void> _delete(Snippet snippet) async {
    await _repo.delete(snippet.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Сниппеты')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SearchBar(
              hintText: 'Поиск сниппетов...',
              onChanged: (v) => setState(() {
                _query = v;
                _applyFilter();
              }),
              leading: const Icon(Icons.search),
            ),
          ),
          if (_allTags.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _allTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FilterChip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                        _applyFilter();
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(_query.isNotEmpty || _selectedTags.isNotEmpty
                        ? 'Ничего не найдено'
                        : 'Нет сниппетов',
                        style: theme.textTheme.bodyLarge))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final s = _filtered[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(s.language,
                              style: theme.textTheme.bodySmall),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (s.tags.isNotEmpty)
                                SizedBox(
                                  width: 80,
                                  child: Text(s.tags.join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall),
                                ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                onPressed: () => _delete(s),
                              ),
                            ],
                          ),
                          onTap: () => _open(s),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

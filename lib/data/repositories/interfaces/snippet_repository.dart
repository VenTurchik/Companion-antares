import '../../../models/snippet.dart';

abstract class SnippetRepository {
  Future<List<Snippet>> getAll();
  Future<void> create(Snippet snippet);
  Future<void> update(Snippet snippet);
  Future<void> delete(String id);
}

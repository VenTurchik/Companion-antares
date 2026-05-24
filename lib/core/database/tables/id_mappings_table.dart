import 'package:sqflite/sqflite.dart';

class IdMappingsTable {
  final Database db;
  IdMappingsTable(this.db);

  static const tableName = 'id_mappings';

  Future<void> save(String localId, String remoteId, String entityType) async {
    await db.insert(
      tableName,
      {
        'local_id': localId,
        'remote_id': remoteId,
        'entity_type': entityType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getLocalId(String entityType, String remoteId) async {
    final rows = await db.query(
      tableName,
      where: 'entity_type = ? AND remote_id = ?',
      whereArgs: [entityType, remoteId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['local_id'] as String;
  }

  Future<String?> getRemoteId(String entityType, String localId) async {
    final rows = await db.query(
      tableName,
      where: 'entity_type = ? AND local_id = ?',
      whereArgs: [entityType, localId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['remote_id'] as String;
  }

  Future<void> deleteByLocalId(String entityType, String localId) async {
    await db.delete(
      tableName,
      where: 'entity_type = ? AND local_id = ?',
      whereArgs: [entityType, localId],
    );
  }

  Future<Map<String, String>> getAllMappings(String entityType) async {
    final rows = await db.query(
      tableName,
      where: 'entity_type = ?',
      whereArgs: [entityType],
    );
    return {for (final r in rows) r['local_id'] as String: r['remote_id'] as String};
  }
}

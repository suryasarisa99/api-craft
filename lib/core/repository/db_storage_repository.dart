import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/database/database_helper.dart';
import 'package:api_craft/core/models/models.dart';

import 'package:flutter/cupertino.dart';
import 'package:nanoid/nanoid.dart';
import 'package:sqflite/sqflite.dart';
import 'storage_repository.dart';

class DbStorageRepository implements StorageRepository {
  final Future<Database> _db;
  final String collectionId; // <--- The Filter

  DbStorageRepository(this._db, String? _collectionId)
    : collectionId = _collectionId ?? kDefaultCollection.id {
    if (_collectionId == null) {
      // Ensure default collection exists
      createDefaultCollection();
    }
  }

  Future<void> createDefaultCollection() async {
    // final db = await _db;
    // debugPrint("db::create-default-collection ${kDefaultCollection}");
    // await db.insert('collections', kDefaultCollection.toMap());
  }

  @override
  Future<List<Node>> getNodes() async {
    final db = await _db;

    final maps = await db.query(
      'nodes',
      columns: [
        'id',
        'parent_id',
        'name',
        'type',
        'method',
        'sort_order',
        'request_type',
        'url',
        'status_code',
      ],
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'sort_order ASC',
    );
    // debugPrint("db::get-contents ${maps}");

    return maps.map((m) => Node.fromMap(m)).toList();
  }

  // @override
  // Future<List<Node>> getContents(String? parentId) async {
  //   final db = await _db;
  //   // If parentId is null, we look for root items (parent_id IS NULL)
  //   // AND strictly filter by collection_id
  //   final whereClause = parentId == null
  //       ? 'collection_id = ? AND parent_id IS NULL'
  //       : 'collection_id = ? AND parent_id = ?';

  //   final whereArgs = parentId == null
  //       ? [collectionId]
  //       : [collectionId, parentId];

  //   final maps = await db.query(
  //     'nodes',
  //     columns: ['id', 'parent_id', 'name', 'type', 'method', 'sort_order'],
  //     where: whereClause,
  //     whereArgs: whereArgs,
  //     orderBy: 'sort_order ASC',
  //   );
  //   debugPrint("db::get-contents ${maps}");

  //   return maps.map((m) => Node.fromMap(m)).toList();
  // }

  @override
  Future<Map<String, dynamic>> getNodeDetails(String id) async {
    final db = await _db;
    final res = await db.query(
      'nodes',
      columns: [
        'headers',
        'auth',
        'query_parameters',
        'variables',
        'description',
        'body_type',
        'scripts',
        'history_id',
      ],
      where: 'id = ?',
      whereArgs: [id],
    );
    // debugPrint("db::get-node-details $id: $res");
    if (res.isEmpty) return {};
    return res.first;
  }

  @override
  Future<String?> getBody(String id) async {
    final db = await _db;
    final res = await db.query(
      'nodes',
      columns: ['body'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (res.isEmpty) return null;
    return res.first['body'] as String?;
  }

  @override
  Future<void> updateNode(Node node) async {
    final db = await _db;
    // debugPrint("db::update-node ${node.id}: ${node.toMap()}");
    await db.update(
      'nodes',
      node.toMap(),
      where: 'id = ?',
      whereArgs: [node.id],
    );
  }

  @override
  Future<void> updateRequestBody(String id, String body) async {
    final db = await _db;
    await db.update('nodes', {'body': body}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateScripts(String id, String scripts) async {
    final db = await _db;
    await db.update(
      'nodes',
      {'scripts': scripts},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<String> createItem({
    required String? parentId,
    required String name,
    required NodeType type,
    String? requestType,
    String? method,
  }) async {
    final db = await _db;
    final newId = nanoid();
    debugPrint('db::create-item $collectionId with ID $newId');

    // Get max sort order for this specific folder
    // Note: We must also filter by collection_id here!
    final res = await db.rawQuery(
      'SELECT MAX(sort_order) as maxOrd FROM nodes WHERE collection_id = ? AND parent_id = ?',
      [collectionId, parentId],
    );
    int nextOrder = (res.first['maxOrd'] as int? ?? 0) + 1;

    await db.insert('nodes', {
      'id': newId,
      'collection_id': collectionId, // <--- Key relation
      'parent_id': parentId,
      'name': name,
      'type': type.toString(),
      'sort_order': nextOrder,
      'request_type': requestType,
      'method': method,
    });

    return newId;
  }

  @override
  Future<void> deleteItem(String id) async {
    final db = await _db;
    // Recursive delete logic needs to happen here or via Cascade in DB schema
    // Since we used ON DELETE CASCADE in creation, deleting the item is enough!
    await db.delete(
      'nodes',
      where: 'id = ? AND collection_id = ?',
      whereArgs: [id, collectionId],
    );
  }

  @override
  Future<void> deleteItems(List<String> ids) async {
    final db = await _db;
    // Batch delete for multiple IDs
    final idPlaceholders = List.filled(ids.length, '?').join(', ');
    await db.delete(
      'nodes',
      where: 'id IN ($idPlaceholders) AND collection_id = ?',
      whereArgs: [...ids, collectionId],
    );
  }

  @override
  Future<String?> renameItem(String id, String newName) async {
    final db = await _db;
    await db.update(
      'nodes',
      {'name': newName},
      where: 'id = ? AND collection_id = ?',
      whereArgs: [id, collectionId],
    );
    return id;
  }

  @override
  Future<String?> moveItem(String id, String? newParentId) async {
    final db = await _db;
    await db.update(
      'nodes',
      {'parent_id': newParentId},
      where: 'id = ? AND collection_id = ?',
      whereArgs: [id, collectionId],
    );
    return id;
  }

  // Other methods...
  @override
  Future<void> saveSortOrder(String? parentId, List<String> orderedIds) async {
    final db = await _db;
    // In DB mode, we receive IDs. We update the integer column.
    final batch = db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(
        'nodes',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  // repository/storage_repository.dart
  @override
  Future<void> createMany(List<Node> nodes) async {
    final db = await _db;
    final batch = db.batch();

    for (final node in nodes) {
      final map = node.toMap();
      map['collection_id'] = collectionId;
      batch.insert('nodes', map);
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<void> createOne(Node node) async {
    final db = await _db;
    final map = node.toMap();
    // debugPrint('db::create-one-node ${node.id}: $map');
    map['collection_id'] = collectionId;
    await db.insert('nodes', map);
  }

  // ... inside StorageRepository

  /// Adds a history entry and enforces the limit (e.g., max 10)

  @override
  Future<void> setHistoryIndex(String requestId, String? historyId) async {
    final db = await _db;
    await db.update(
      Tables.nodes,
      {'history_id': historyId},
      where: 'id = ? AND collection_id = ?',
      whereArgs: [requestId, collectionId],
    );
  }

  /// Clear history for a node

  // --- Environments ---
  @override
  Future<List<Environment>> getEnvironments(String collectionId) async {
    final db = await _db;
    final res = await db.query(
      'environments',
      where: 'collection_id = ?',
      whereArgs: [collectionId],
    );
    return res.map((e) => Environment.fromMap(e)).toList();
  }

  @override
  Future<void> createEnvironment(Environment env) async {
    final db = await _db;
    await db.insert(
      'environments',
      env.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateEnvironment(Environment env) async {
    final db = await _db;
    await db.update(
      'environments',
      env.toMap(),
      where: 'id = ?',
      whereArgs: [env.id],
    );
  }

  @override
  Future<void> deleteEnvironment(String id) async {
    final db = await _db;
    await db.delete('environments', where: 'id = ?', whereArgs: [id]);
  }
}

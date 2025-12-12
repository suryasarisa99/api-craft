import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'storage_repository.dart';

class DbStorageRepository implements StorageRepository {
  final Future<Database> _db;
  final String collectionId; // <--- The Filter
  final Uuid _uuid = const Uuid();

  DbStorageRepository(this._db, String? _collectionId)
    : collectionId = _collectionId ?? kDefaultCollection.id {
    if (_collectionId == null) {
      // Ensure default collection exists
      createDefaultCollection();
    }
  }

  Future<void> createDefaultCollection() async {
    final db = await _db;
    await db.insert('collections', kDefaultCollection.toMap());
  }

  @override
  Future<List<Node>> getNodes() async {
    final db = await _db;

    final maps = await db.query(
      'nodes',
      columns: ['id', 'parent_id', 'name', 'type', 'method', 'sort_order'],
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'sort_order ASC',
    );
    debugPrint("db::get-contents ${maps}");

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
        'variables',
        'description',
      ], // Fetch only config cols
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint("db::get-node-details $id: $res");
    if (res.isEmpty) return {};
    return res.first;
  }

  @override
  Future<void> updateNode(Node node) async {
    final db = await _db;
    debugPrint("db::update-node ${node.id}: ${node.toMap()}");
    await db.update(
      'nodes',
      node.toMap(),
      where: 'id = ?',
      whereArgs: [node.id],
    );
  }

  @override
  Future<String> createItem({
    required String? parentId,
    required String name,
    required NodeType type,
  }) async {
    final db = await _db;
    final newId = _uuid.v4();
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
      batch.insert('nodes', map);
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<void> createOne(Node node) async {
    final db = await _db;
    final map = node.toMap();
    debugPrint('db::create-one-node ${node.id}: $map');
    map['collection_id'] = collectionId;
    await db.insert('nodes', map);
  }
}

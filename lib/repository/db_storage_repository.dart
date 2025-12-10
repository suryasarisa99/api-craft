import 'dart:convert';

import 'package:api_craft/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'storage_repository.dart';

class DbStorageRepository implements StorageRepository {
  final Database db;
  final String collectionId; // <--- The Filter
  final Uuid _uuid = const Uuid();

  DbStorageRepository(this.db, this.collectionId);

  @override
  Future<List<Node>> getContents(String? parentId) async {
    // If parentId is null, we look for root items (parent_id IS NULL)
    // AND strictly filter by collection_id
    final whereClause = parentId == null
        ? 'collection_id = ? AND parent_id IS NULL'
        : 'collection_id = ? AND parent_id = ?';

    final whereArgs = parentId == null
        ? [collectionId]
        : [collectionId, parentId];

    final maps = await db.query(
      'nodes',
      columns: ['id', 'parent_id', 'name', 'type', 'method', 'sort_order'],
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'sort_order ASC',
    );

    return maps.map((m) => Node.fromMap(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> getNodeDetails(String id) async {
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

    if (res.isEmpty) return {};
    return res.first;
  }

  @override
  Future<void> updateNode(Node node) async {
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
    final newId = _uuid.v4();
    debugPrint('Creating item in collection $collectionId with ID $newId');

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
    // Recursive delete logic needs to happen here or via Cascade in DB schema
    // Since we used ON DELETE CASCADE in creation, deleting the item is enough!
    await db.delete(
      'nodes',
      where: 'id = ? AND collection_id = ?',
      whereArgs: [id, collectionId],
    );
  }

  @override
  Future<String?> renameItem(String id, String newName) async {
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

  @override
  Future<void> duplicateItem(String id) async {
    // 1. Fetch the original item to start the process
    final maps = await db.query(
      'nodes',
      where: 'id = ? AND collection_id = ?',
      whereArgs: [id, collectionId],
    );
    if (maps.isEmpty) return;

    final original = maps.first;
    final parentId = original['parent_id'] as String?;

    // 2. Start Recursive Copy
    await _recursiveCopy(
      sourceId: id,
      targetParentId: parentId,
      nameOverride: "${original['name']}_copy",
    );
  }

  /// Deep Copying
  Future<void> _recursiveCopy({
    required String sourceId,
    required String? targetParentId,
    String? nameOverride,
  }) async {
    // A. Fetch Source Data
    final maps = await db.query(
      'nodes',
      where: 'id = ? AND collection_id = ?',
      whereArgs: [sourceId, collectionId],
    );
    if (maps.isEmpty) return;
    final source = maps.first;

    // B. Generate New ID
    final newId = _uuid.v4();
    final newName = nameOverride ?? (source['name'] as String);
    final typeStr = source['type'] as String;

    // C. Calculate Sort Order
    // - If nameOverride is set (Top Level), put it at the bottom (MAX + 1).
    // - If null (Child), keep original sort_order to preserve the folder structure exactly.
    int sortOrder = source['sort_order'] as int;

    if (nameOverride != null) {
      final whereClause = targetParentId == null
          ? 'collection_id = ? AND parent_id IS NULL'
          : 'collection_id = ? AND parent_id = ?';
      final args = targetParentId == null
          ? [collectionId]
          : [collectionId, targetParentId];

      final res = await db.rawQuery(
        'SELECT MAX(sort_order) as maxOrd FROM nodes WHERE $whereClause',
        args,
      );
      sortOrder = (res.first['maxOrd'] as int? ?? 0) + 1;
    }

    // D. Insert the Copy
    await db.insert('nodes', {
      'id': newId,
      'collection_id': collectionId,
      'parent_id': targetParentId,
      'name': newName,
      'type': typeStr,
      'method': source['method'], // Copy request fields
      'url': source['url'],
      'body': source['body'],
      'sort_order': sortOrder,
    });

    // E. Recursion: If it's a folder, copy its children
    if (typeStr == NodeType.folder.toString()) {
      final children = await db.query(
        'nodes',
        where: 'parent_id = ? AND collection_id = ?',
        whereArgs: [sourceId, collectionId],
      );

      for (final child in children) {
        await _recursiveCopy(
          sourceId: child['id'] as String,
          targetParentId:
              newId, // <--- Key: Parent is the NEW folder we just made
          nameOverride: null, // Keep original name for children
        );
      }
    }
  }

  // @override
  // Future<NodeConfig> getNodeConfig(String id) async {
  //   final res = await db.query(
  //     'nodes',
  //     // Fetch specific config columns
  //     columns: ['description', 'headers', 'auth', 'variables'],
  //     where: 'id = ? AND collection_id = ?',
  //     whereArgs: [id, collectionId],
  //   );

  //   if (res.isEmpty) return const NodeConfig();

  //   final row = res.first;

  //   return NodeConfig(
  //     description: row['description'] as String? ?? '',
  //     headers: row['headers'] != null
  //         ? Map<String, String>.from(jsonDecode(row['headers'] as String))
  //         : const {},
  //     variables: row['variables'] != null
  //         ? Map<String, String>.from(jsonDecode(row['variables'] as String))
  //         : const {},
  //     auth: row['auth'] != null ? jsonDecode(row['auth'] as String) : null,
  //   );
  // }

  // @override
  // Future<void> saveNodeConfig(String id, NodeConfig config) async {
  //   await db.update(
  //     'nodes',
  //     {
  //       'description': config.description,
  //       'headers': jsonEncode(config.headers),
  //       'variables': jsonEncode(config.variables),
  //       'auth': config.auth != null ? jsonEncode(config.auth) : null,
  //     },
  //     where: 'id = ? AND collection_id = ?',
  //     whereArgs: [id, collectionId],
  //   );
  // }
}

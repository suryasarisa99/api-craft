import 'dart:convert';
import 'dart:io';

import 'package:api_craft/core/models/models.dart';

import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';
import 'package:api_craft/features/request/models/websocket_session.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:nanoid/nanoid.dart';

class FlatFileStorageRepository implements StorageRepository {
  final Directory rootDir;
  final DbStorageRepository dbRepo;

  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  FlatFileStorageRepository({required String rootPath, required this.dbRepo})
    : rootDir = Directory(rootPath);

  // --- Helper: File Access ---

  File _getFileForId(String id) {
    // Try request prefix
    final reqFile = File(p.join(rootDir.path, 'rq_$id.json'));
    if (reqFile.existsSync()) return reqFile;

    // Try folder prefix
    final folderFile = File(p.join(rootDir.path, 'fl_$id.json'));
    if (folderFile.existsSync()) return folderFile;

    // Try environment prefix (shared)
    final envFile = File(p.join(rootDir.path, 'env_$id.json'));
    if (envFile.existsSync()) return envFile;

    // Default to request if creating? No, this is for existing.
    // If we don't know type, we can't deterministically return a file unless we search.
    // But usually we know the type context or we search.
    return reqFile; // Fallback?
  }

  File _getFileForNode(String id, NodeType type) {
    final prefix = type == NodeType.folder ? 'fl' : 'rq';
    return File(p.join(rootDir.path, '${prefix}_$id.json'));
  }

  File _getFileForEnv(String id) {
    return File(p.join(rootDir.path, 'env_$id.json'));
  }

  // --- StorageRepository Implementation ---

  @override
  Future<List<Node>> getNodes() async {
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
      return [];
    }

    final nodes = <Node>[];
    final entities = rootDir
        .listSync(); // Synchronous listing is okay for local FS usually, or use await list().toList()

    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = p.basename(entity.path);
        // Filter by prefix
        if (!filename.startsWith('rq_') && !filename.startsWith('fl_')) {
          continue;
        }

        try {
          final content = await entity.readAsString();
          final map = jsonDecode(content) as Map<String, dynamic>;
          final node = Node.fromMap(map);
          // Hydrate immediately since we have the full content in the file
          node.hydrate(map);
          nodes.add(node);
        } catch (e) {
          debugPrint('Error parsing node file $filename: $e');
        }
      }
    }

    // Sort by sort_order
    nodes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return nodes;
  }

  @override
  Future<Map<String, dynamic>> getNodeDetails(String id) async {
    // In flat file mode, details are in the same file.
    // We can re-read the file or assume getNodes already fully loaded it (which we did by calling hydrate).
    // The provider might call this to "lazy load" but we are eager.
    // So we just return the map from the file.
    final file = _getFileForId(id);
    if (!file.existsSync()) return {};

    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<String?> getBody(String id) async {
    // Body is in the file too (for requests)
    final file = _getFileForId(id);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final map = jsonDecode(content);
      return map['body'] as String?; // RequestNode stores body in 'body'
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> createItem({
    required String? parentId,
    required String name,
    required NodeType type,
    String? requestType,
    String? method,
  }) async {
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }

    final newId = nanoid();
    final file = _getFileForNode(newId, type);

    // Calculate sort order: simplistic approach, append to end?
    // Reading all nodes to find max sort order is cleaner but slower.
    // For now, allow 0 or rely on reorder.
    // Creating "one" usually implies appending.
    // Let's perform a quick scan of "siblings".
    // Actually, `getNodes` is cached by provider? Repo doesn't have cache.
    // We'll read all files. If performance is issue, we optimize.
    // Let's stick to 0 and let UI handle it, or standard large int?
    // If we duplicate logic from getNodes, it's consistent.
    // Let's assume 0 for now to keep it fast.

    final map = {
      'id': newId,
      'parent_id': parentId,
      'name': name,
      'type': type.toString(),
      'sort_order': 0, // Default
      if (type == NodeType.request) ...{
        'request_type': requestType,
        'method': method,
        'url': '',
        'body': '',
        'status_code': null,
      },
      // Config fields (empty defaults)
      'description': '',
      'headers': '[]',
      'auth': null,
      'variables': '[]',
      if (type == NodeType.request) ...{
        'query_parameters': '[]',
        'body_type': null,
        'scripts': null,
      },
    };

    await file.writeAsString(_jsonEncoder.convert(map));
    return newId;
  }

  @override
  Future<void> createOne(Node node) async {
    await createMany([node]);
  }

  @override
  Future<void> createMany(List<Node> nodes) async {
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    for (final node in nodes) {
      final file = _getFileForNode(node.id, node.type);
      final map = node.toMap();
      await file.writeAsString(_jsonEncoder.convert(map));
    }
  }

  @override
  Future<void> updateNode(Node node) async {
    final file = _getFileForNode(node.id, node.type);
    // Overwrite with new map
    await file.writeAsString(_jsonEncoder.convert(node.toMap()));
  }

  @override
  Future<void> deleteItem(String id) async {
    final file = _getFileForId(id);
    if (await file.exists()) {
      await file.delete();
    }
    // Also delete children?
    // File structure is flat, children just have parent_id = id.
    // We need to recursively find children and delete them!
    // DB assumes Cascade Delete. Files don't have that.
    // We must scan for children.
    final allNodes = await getNodes(); // Re-read to be safe
    final children = allNodes.where((n) => n.parentId == id).toList();
    for (final child in children) {
      await deleteItem(child.id); // Recursive
    }
  }

  @override
  Future<void> deleteItems(List<String> ids) async {
    for (final id in ids) {
      await deleteItem(id);
    }
  }

  @override
  Future<String?> renameItem(String id, String newName) async {
    final file = _getFileForId(id);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final map = jsonDecode(content) as Map<String, dynamic>;
    map['name'] = newName;
    await file.writeAsString(_jsonEncoder.convert(map));
    return id; // ID unchanged
  }

  @override
  Future<String?> moveItem(String id, String? newParentId) async {
    final file = _getFileForId(id);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final map = jsonDecode(content) as Map<String, dynamic>;
    map['parent_id'] = newParentId;
    await file.writeAsString(_jsonEncoder.convert(map));
    return id; // ID unchanged
  }

  @override
  Future<void> saveSortOrder(String? parentId, List<String> orderedIds) async {
    // We need to update sort_order in each file.
    for (int i = 0; i < orderedIds.length; i++) {
      final id = orderedIds[i];
      final file = _getFileForId(id);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final map = jsonDecode(content) as Map<String, dynamic>;
          if (map['sort_order'] != i) {
            map['sort_order'] = i;
            await file.writeAsString(_jsonEncoder.convert(map));
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> updateRequestBody(String id, String body) async {
    final file = _getFileForNode(id, NodeType.request);
    if (await file.exists()) {
      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      map['body'] = body;
      await file.writeAsString(_jsonEncoder.convert(map));
    }
  }

  @override
  Future<void> updateScripts(String id, String scripts) async {
    final file = _getFileForId(id);
    if (await file.exists()) {
      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      map['scripts'] = scripts;
      await file.writeAsString(_jsonEncoder.convert(map));
    }
  }

  // --- Environments (Hybrid) ---

  @override
  Future<List<Environment>> getEnvironments(String collectionId) async {
    // 1. Get private/local envs from DB
    final privateEnvs = await dbRepo.getEnvironments(collectionId);

    // 2. Get shared envs from Files (env_*.json)
    final sharedEnvs = <Environment>[];
    if (await rootDir.exists()) {
      final entities = rootDir.listSync();
      for (var entity in entities) {
        if (entity is File &&
            p.basename(entity.path).startsWith('env_') &&
            entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final map = jsonDecode(content) as Map<String, dynamic>;
            // Verify collection ID matches?
            // User might copy env file from another collection?
            // FlatFileRepo is usually rooted PER collection?
            // DbRepo takes collectionId.
            // If rootDir IS the collection folder, then all files implicitly belong to it.
            // But map might have 'collection_id'. Let's check.
            if (map['collection_id'] == collectionId) {
              sharedEnvs.add(Environment.fromMap(map));
            }
          } catch (_) {}
        }
      }
    }

    return [...privateEnvs, ...sharedEnvs];
  }

  @override
  Future<void> createEnvironment(Environment env) async {
    if (env.isShared) {
      final file = _getFileForEnv(env.id);
      await file.writeAsString(_jsonEncoder.convert(env.toMap()));
    } else {
      await dbRepo.createEnvironment(env);
    }
  }

  @override
  Future<void> updateEnvironment(Environment env) async {
    // Check if it WAS shared or private?
    // If user toggles shared status:
    // - Shared -> Private: Delete file, Insert DB.
    // - Private -> Shared: Delete DB, Create File.

    // Current implementation of 'update' in logic typically keeps state consistent.
    // But `env` passed here is the NEW state.

    // Optimization: Just do write to new target, and try delete on old target?
    // Or just write to target based on `isShared`.

    if (env.isShared) {
      // Should be in File
      // Ensure not in DB
      await dbRepo.deleteEnvironment(env.id);

      final file = _getFileForEnv(env.id);
      await file.writeAsString(_jsonEncoder.convert(env.toMap()));
    } else {
      // Should be in DB
      // Ensure not in File
      final file = _getFileForEnv(env.id);
      if (await file.exists()) await file.delete();

      await dbRepo.updateEnvironment(env);
      // Note: updateEnvironment in DB might fail if ID doesn't exist (because it was in file).
      // So we should probably use createEnvironment logic (replace)?
      // DbRepo.createEnvironment uses `insert OR replace`.
      // But updateEnvironment uses `update`.
      // Let's safe bet: createEnvironment (upsert).
      await dbRepo.createEnvironment(env);
    }
  }

  @override
  Future<void> deleteEnvironment(String id) async {
    await dbRepo.deleteEnvironment(id);
    final file = _getFileForEnv(id);
    if (await file.exists()) await file.delete();
  }

  // --- Delegated to DB (Private Data) ---

  @override
  Future<void> updateCollectionSelection(
    String collectionId,
    String? envId,
    String? jarId,
  ) => dbRepo.updateCollectionSelection(collectionId, envId, jarId);

  @override
  Future<void> addHistoryEntry(RawHttpResponse entry, {int limit = 10}) =>
      dbRepo.addHistoryEntry(entry, limit: limit);

  @override
  Future<List<RawHttpResponse>> getHistory(
    String requestId, {
    int limit = 10,
  }) => dbRepo.getHistory(requestId, limit: limit);

  @override
  Future<void> setHistoryIndex(String requestId, String? historyId) async {
    // history_id is in Node content. So we update Node file!
    // Not DB.
    // Although details says "rest will be store in database like history",
    // `history_id` is a pointer IN the node config.
    // So we must update the node file.
    final file = _getFileForId(requestId);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        map['history_id'] = historyId; // request uses 'history_id'
        await file.writeAsString(_jsonEncoder.convert(map));
      } catch (_) {}
    }
  }

  @override
  Future<void> clearHistory(String requestId) => dbRepo.clearHistory(requestId);

  @override
  Future<void> deleteCurrHistory(String historyId) =>
      dbRepo.deleteCurrHistory(historyId);

  @override
  Future<void> clearHistoryForCollection() =>
      dbRepo.clearHistoryForCollection();

  @override
  Future<List<CookieJarModel>> getCookieJars(String collectionId) =>
      dbRepo.getCookieJars(collectionId);

  @override
  Future<void> createCookieJar(CookieJarModel jar) =>
      dbRepo.createCookieJar(jar);

  @override
  Future<void> updateCookieJar(CookieJarModel jar) =>
      dbRepo.updateCookieJar(jar);

  @override
  Future<void> deleteCookieJar(String id) => dbRepo.deleteCookieJar(id);

  @override
  Future<void> createWebSocketSession(WebSocketSession session) =>
      dbRepo.createWebSocketSession(session);

  @override
  Future<void> updateWebSocketSession(WebSocketSession session) =>
      dbRepo.updateWebSocketSession(session);

  @override
  Future<List<WebSocketSession>> getWebSocketSessions(String requestId) =>
      dbRepo.getWebSocketSessions(requestId);

  @override
  Future<void> deleteWebSocketSession(String sessionId) =>
      dbRepo.deleteWebSocketSession(sessionId);

  @override
  Future<void> addWebSocketMessage(WebSocketMessage msg) =>
      dbRepo.addWebSocketMessage(msg);

  @override
  Future<List<WebSocketMessage>> getWebSocketMessages(
    String sessionId, {
    int limit = 100,
  }) => dbRepo.getWebSocketMessages(sessionId, limit: limit);

  @override
  Future<void> clearWebSocketSessionMessages(String sessionId) =>
      dbRepo.clearWebSocketSessionMessages(sessionId);

  @override
  Future<void> clearWebSocketHistory(String requestId) =>
      dbRepo.clearWebSocketHistory(requestId);
}

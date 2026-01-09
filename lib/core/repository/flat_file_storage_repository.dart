import 'dart:convert';
import 'dart:io';

import 'package:api_craft/core/models/models.dart';

import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:nanoid/nanoid.dart';

class FlatFileStorageRepository implements StorageRepository {
  final Directory rootDir;
  FlatFileStorageRepository({required String rootPath})
    : rootDir = Directory(rootPath);

  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  // --- Helper: File Access ---

  File _getFileForId(String id) {
    // Try request prefix
    final reqFile = File(p.join(rootDir.path, 'rq_$id.json'));
    if (reqFile.existsSync()) return reqFile;

    // Try folder prefix
    final folderFile = File(p.join(rootDir.path, 'fl_$id.json'));
    if (folderFile.existsSync()) return folderFile;

    // Default to request if creating? No, this is for existing.
    // If we don't know type, we can't deterministically return a file unless we search.
    // But usually we know the type context or we search.
    return reqFile; // Fallback?
  }

  File _getNodeFile(String id, NodeType type) {
    final prefix = type == NodeType.folder ? 'fl' : 'rq';
    return File(p.join(rootDir.path, '${prefix}_$id.json'));
  }

  File _getEnvFile(String id) {
    // Environments are now stored in `env` subdirectory
    return File(p.join(rootDir.path, 'env', '$id.json'));
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
    final file = _getNodeFile(newId, type);

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
      final file = _getNodeFile(node.id, node.type);
      final map = node.toMap();
      await file.writeAsString(_jsonEncoder.convert(map));
    }
  }

  @override
  Future<void> updateNode(Node node) async {
    final file = _getNodeFile(node.id, node.type);
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
    final file = _getNodeFile(id, NodeType.request);
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

  @override
  Future<List<Environment>> getEnvironments(String collectionId) async {
    final sharedEnvs = <Environment>[];
    final envDir = Directory(p.join(rootDir.path, 'env'));

    if (await envDir.exists()) {
      final entities = envDir.listSync();
      for (var entity in entities) {
        if (entity is File &&
            !p.basename(entity.path).startsWith('.') && // Ignore hidden files
            entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final map = jsonDecode(content) as Map<String, dynamic>;
            sharedEnvs.add(Environment.fromMap(map));
          } catch (_) {}
        }
      }
    }

    return sharedEnvs;
  }

  @override
  Future<void> createEnvironment(Environment env) async {
    if (env.isShared) {
      final file = _getEnvFile(env.id);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(_jsonEncoder.convert(env.toMap()));
    }
  }

  @override
  Future<void> updateEnvironment(Environment env) async {
    if (env.isShared) {
      final file = _getEnvFile(env.id);
      await file.writeAsString(_jsonEncoder.convert(env.toMap()));
    }
  }

  @override
  Future<void> deleteEnvironment(String id) async {
    final file = _getEnvFile(id);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> setHistoryIndex(String requestId, String? historyId) async {
    final file = _getNodeFile(requestId, NodeType.request);
    if (await file.exists()) {
      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      // history_id is in config? No, RequestNode has it in config.
      // But usually top level map mirrors Node structure.
      // Node.fromMap expects 'config'.
      // Only 'config' map needs update?
      // RequestNode.toMap puts it in 'config' -> 'history_id'.
      // So we need to update map['config']['history_id'].
      if (map['config'] != null && map['config'] is Map) {
        map['config']['history_id'] = historyId;
        await file.writeAsString(_jsonEncoder.convert(map));
      }
    }
  }
}

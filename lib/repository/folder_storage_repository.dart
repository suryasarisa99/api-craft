import 'dart:convert';
import 'dart:io';
import 'package:api_craft/models/models.dart';
import 'package:path/path.dart' as p;
import 'storage_repository.dart';

class FolderStorageRepository implements StorageRepository {
  final String rootPath;

  FolderStorageRepository({required this.rootPath});

  @override
  Future<List<Node>> getContents(String? parentId) async {
    // If parentId is null/empty, we are at Root
    final dirPath = (parentId == null || parentId.isEmpty)
        ? rootPath
        : parentId;
    final dir = Directory(dirPath);

    if (!await dir.exists()) return [];

    final entities = await dir.list().toList();
    final List<Node> nodes = [];

    // 1. Load Nodes
    for (var entity in entities) {
      final name = p.basename(entity.path);
      if (name.startsWith('.') ||
          name == 'folder.json' ||
          name == 'collection.json') {
        continue;
      }
      final type = await FileSystemEntity.isDirectory(entity.path)
          ? NodeType.folder
          : NodeType.request;
      final newNode = type == NodeType.folder
          ? FolderNode(
              id: entity.path,
              parentId: parentId,
              name: name,
              config: FolderNodeConfig.empty(),
            )
          : RequestNode(
              id: entity.path,
              parentId: parentId,
              name: name,
              config: RequestNodeConfig.empty(),
            );
      nodes.add(newNode);
    }

    // 2. Load Sort Order
    List<String> sortOrder = [];
    final configFile = File(
      p.join(dirPath, dirPath == rootPath ? 'collection.json' : 'folder.json'),
    );
    if (await configFile.exists()) {
      try {
        final data = jsonDecode(await configFile.readAsString());
        // In FS mode, we sort by NAME because IDs (paths) are long/variable
        sortOrder = List<String>.from(data['seq'] ?? []);
      } catch (_) {}
    }

    // 3. Sort
    nodes.sort((a, b) {
      int idxA = sortOrder.indexOf(a.name);
      int idxB = sortOrder.indexOf(b.name);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      if (a.type == b.type) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return a.type == NodeType.folder ? -1 : 1;
    });

    return nodes;
  }

  @override
  Future<Map<String, dynamic>> getNodeDetails(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<String> createItem({
    required String? parentId,
    required String name,
    required NodeType type,
  }) async {
    final parent = parentId ?? rootPath;
    final finalName = (type == NodeType.request && !name.endsWith('.json'))
        ? '$name.json'
        : name;
    final newPath = p.join(parent, finalName);

    if (type == NodeType.folder) {
      await Directory(newPath).create();
      // Create metadata file
      await File(
        p.join(newPath, 'folder.json'),
      ).writeAsString(jsonEncode({'name': name}));
    } else {
      await File(
        newPath,
      ).writeAsString(jsonEncode({'method': 'GET', 'url': ''}));
    }
    return newPath; // Return the new ID (Path)
  }

  @override
  Future<void> deleteItem(String id) async {
    if (await FileSystemEntity.isDirectory(id)) {
      await Directory(id).delete(recursive: true);
    } else {
      await File(id).delete();
    }
  }

  @override
  Future<String?> renameItem(String id, String newName) async {
    final parent = p.dirname(id);
    final isDir = await FileSystemEntity.isDirectory(id);

    // Preserve extension for files if user didn't type it
    String finalName = newName;
    if (!isDir && !newName.endsWith('.json') && id.endsWith('.json')) {
      finalName = '$newName.json';
    }

    final newPath = p.join(parent, finalName);
    if (id == newPath) return id;

    await (isDir ? Directory(id).rename(newPath) : File(id).rename(newPath));

    // Also update the sort order in parent config to reflect new name
    await _updateNameInConfig(parent, p.basename(id), finalName);

    return newPath; // ID Changed!
  }

  @override
  Future<String?> moveItem(String id, String? newParentId) async {
    final fileName = p.basename(id);
    final newPath = p.join(newParentId ?? rootPath, fileName);

    if (id == newPath) return id;

    if (await FileSystemEntity.isDirectory(id)) {
      await Directory(id).rename(newPath);
    } else {
      await File(id).rename(newPath);
    }
    return newPath; // ID Changed!
  }

  @override
  Future<void> saveSortOrder(
    String? parentId,
    List<String> orderedNames,
  ) async {
    final dirPath = parentId ?? rootPath;
    final configFile = File(
      p.join(dirPath, dirPath == rootPath ? 'collection.json' : 'folder.json'),
    );

    Map<String, dynamic> data = {};
    if (await configFile.exists()) {
      try {
        data = jsonDecode(await configFile.readAsString());
      } catch (_) {}
    }
    data['seq'] = orderedNames;

    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  // Helper to keep 'folder.json' in sync when renaming
  Future<void> _updateNameInConfig(
    String parentPath,
    String oldName,
    String newName,
  ) async {
    // Read parent config, find oldName in 'seq', replace with newName, write back.
    // ... logic same as your previous code ...
  }
  @override
  Future<void> duplicateItem(String id) async {
    await copyTo(id, p.dirname(id));
  }

  Future<void> copyTo(String sourcePath, String targetParentPath) async {
    var fileName = p.basename(sourcePath);
    // Handle duplicate names (e.g., "login_copy.json")
    final nameWithoutExt = p.basenameWithoutExtension(sourcePath);
    final ext = p.extension(sourcePath);
    fileName = '${nameWithoutExt}_copy$ext';

    final destination = p.join(targetParentPath, fileName);

    if (await FileSystemEntity.isDirectory(sourcePath)) {
      await Directory(destination).create();

      /// Recursively copy contents
      final sourceDir = Directory(sourcePath);
      await for (var entity in sourceDir.list(recursive: true)) {
        final relativePath = p.relative(entity.path, from: sourcePath);
        final newPath = p.join(destination, relativePath);
        if (entity is Directory) {
          await Directory(newPath).create(recursive: true);
        } else if (entity is File) {
          await File(newPath).create(recursive: true);
          await entity.copy(newPath);
        }
      }
    } else {
      await File(sourcePath).copy(destination);
    }
  }

  // @override
  // Future<NodeConfig> getNodeConfig(String id) async {
  //   // id is the full path in FS mode
  //   final isDir = await FileSystemEntity.isDirectory(id);
  //   final configFile = File(isDir ? p.join(id, 'folder.json') : id);

  //   if (!await configFile.exists()) return const NodeConfig();

  //   try {
  //     final content = await configFile.readAsString();
  //     final map = jsonDecode(content);

  //     return NodeConfig(
  //       description: map['description'] ?? '',
  //       headers: map['headers'] != null
  //           ? Map<String, String>.from(map['headers'])
  //           : const {},
  //       variables: map['variables'] != null
  //           ? Map<String, String>.from(map['variables'])
  //           : const {},
  //       auth: map['auth'],
  //     );
  //   } catch (_) {
  //     return const NodeConfig();
  //   }
  // }

  // @override
  // Future<void> saveNodeConfig(String id, NodeConfig config) async {
  //   final isDir = await FileSystemEntity.isDirectory(id);
  //   final configFile = File(isDir ? p.join(id, 'folder.json') : id);

  //   Map<String, dynamic> currentData = {};
  //   if (await configFile.exists()) {
  //     try {
  //       currentData = jsonDecode(await configFile.readAsString());
  //     } catch (_) {}
  //   }

  //   // Update fields
  //   currentData['description'] = config.description;
  //   currentData['headers'] = config.headers;
  //   currentData['variables'] = config.variables;
  //   currentData['auth'] = config.auth;

  //   // Remove empty fields to keep JSON clean (Optional)
  //   if (config.description.isEmpty) currentData.remove('description');
  //   if (config.headers.isEmpty) currentData.remove('headers');
  //   if (config.variables.isEmpty) currentData.remove('variables');
  //   if (config.auth == null) currentData.remove('auth');

  //   await configFile.writeAsString(
  //     const JsonEncoder.withIndent('  ').convert(currentData),
  //   );
  // }

  @override
  Future<void> updateNode(Node node) async {
    throw UnimplementedError();
  }
}

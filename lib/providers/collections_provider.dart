import 'dart:io';
import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:api_craft/providers/providers.dart';

final collectionsProvider =
    AsyncNotifierProvider<CollectionsNotifier, List<FileNode>>(
      CollectionsNotifier.new,
    );

class CollectionsNotifier extends AsyncNotifier<List<FileNode>> {
  String? _loadedRootPath;

  String get _root => _loadedRootPath ?? '';
  @override
  Future<List<FileNode>> build() async {
    _loadedRootPath = await ref.watch(rootPathProvider.future);
    return _loadCollections();
  }

  Future<List<FileNode>> _loadCollections() async {
    final dir = Directory(_root);
    if (!await dir.exists()) {
      return [];
    }

    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<FileNode> collectionNodes = [];

    for (var entity in entities) {
      final name = p.basename(entity.path);

      // Skip hidden files or specific configs if needed
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        collectionNodes.add(
          FileNode(path: entity.path, name: name, type: NodeType.folder),
        );
      } else {
        collectionNodes.add(
          FileNode(path: entity.path, name: name, type: NodeType.request),
        );
      }
    }

    return collectionNodes;
  }
}

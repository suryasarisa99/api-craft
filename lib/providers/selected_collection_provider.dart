import 'dart:io';
import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final selectedCollectionProvider =
    AsyncNotifierProvider<SelectedCollectionNotifier, FileNode?>(
      SelectedCollectionNotifier.new,
    );

class SelectedCollectionNotifier extends AsyncNotifier<FileNode?> {
  static const _prefKey = 'selected_collection_path';

  @override
  Future<FileNode?> build() async {
    final savedPath = prefs.getString(_prefKey);

    if (savedPath != null) {
      final dir = Directory(savedPath);
      if (await dir.exists()) {
        return FileNode(
          path: savedPath,
          name: p.basename(savedPath),
          type: NodeType.folder,
        );
      }
    }

    // 2. Fallback: If no selection saved (or file deleted), default to the first available collection
    final rootPath = await ref.watch(rootPathProvider.future);
    final rootDir = Directory(rootPath);

    if (await rootDir.exists()) {
      final entities = await rootDir.list().toList();
      // Look for the first directory (e.g., 'api-craft')
      for (var entity in entities) {
        if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
          final firstCollection = FileNode(
            path: entity.path,
            name: p.basename(entity.path),
            type: NodeType.folder,
          );

          // Save this default
          await prefs.setString(_prefKey, firstCollection.path);
          return firstCollection;
        }
      }
    }

    return null; // No collections exist yet
  }

  /// Call this method from your UI when the user clicks a different collection
  Future<void> selectCollection(FileNode collection) async {
    await prefs.setString(_prefKey, collection.path);
    state = AsyncData(collection);
  }
}

// =============== File Tree Provider, Provides File Tree of Selected Collection ===============

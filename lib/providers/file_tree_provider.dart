import 'dart:convert';
import 'dart:io';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/widgets.dart';

final fileTreeProvider =
    AsyncNotifierProvider<FileTreeNotifier, List<FileNode>>(
      FileTreeNotifier.new,
    );

class FileTreeNotifier extends AsyncNotifier<List<FileNode>> {
  String? _loadedCollectionPath;

  String get collectionPath => _loadedCollectionPath ?? '';

  static const _ignoredFiles = {
    'folder.json',
    'collection.json',
    '.DS_Store',
    'desktop.ini',
  };

  @override
  Future<List<FileNode>> build() async {
    final selectedNode = await ref.watch(selectedCollectionProvider.future);
    if (selectedNode == null) return [];
    _loadedCollectionPath = selectedNode.path;
    return _loadDirectory(selectedNode.path);
  }

  Future<List<FileNode>> _loadDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    // 1. Load entities
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<FileNode> nodes = [];

    // 2. Load Sort Order from folder.json (if exists)
    List<String> sortOrder = [];
    final configActionFile = File(
      p.join(dirPath, 'folder.json'),
    ); // For subfolders
    final configRootFile = File(p.join(dirPath, 'collection.json')); // For root

    File? configFile;
    if (await configActionFile.exists()) {
      configFile = configActionFile;
    } else if (await configRootFile.exists()) {
      configFile = configRootFile;
    }

    if (configFile != null) {
      try {
        final content = await configFile.readAsString();
        final json = jsonDecode(content);
        if (json['seq'] != null) {
          sortOrder = List<String>.from(json['seq']);
        }
      } catch (e) {
        // Ignore JSON errors
      }
    }

    // 3. Process Entities
    for (var entity in entities) {
      final name = p.basename(entity.path);

      // FILTER: Skip ignored files and hidden files
      if (name.startsWith('.') || _ignoredFiles.contains(name)) continue;

      if (entity is Directory) {
        nodes.add(
          FileNode(
            path: entity.path,
            name: name,
            type: NodeType.folder,
            children: await _loadDirectory(entity.path), // Recursion
          ),
        );
      } else {
        nodes.add(
          FileNode(path: entity.path, name: name, type: NodeType.request),
        );
      }
    }

    // 4. Custom Sort Logic
    // Sort based on the index in 'sortOrder'. If not found, put at the end.
    nodes.sort((a, b) {
      int indexA = sortOrder.indexOf(a.name);
      int indexB = sortOrder.indexOf(b.name);

      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1; // A is in list, B is not -> A comes first
      if (indexB != -1) return 1; // B is in list, A is not -> B comes first

      // Default fallback: Folders first, then alphabetical
      if (a.type == b.type) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return a.type == NodeType.folder ? -1 : 1;
    });

    return nodes;
  }

  // Method to save new order (Call this after drag & drop reorder)
  Future<void> reorderNodes(
    String parentPath,
    List<String> newOrderNames,
    List<FileNode> optimisticNodes,
  ) async {
    // 1. OPTIMISTIC UPDATE:
    // We manually update the state to the new list immediately so the UI doesn't flicker.
    state = AsyncData(optimisticNodes);

    // 2. DETERMINE CONFIG FILE:
    // If we are at the root, use 'collection.json'. If inside a folder, use 'folder.json'.
    final isRoot = parentPath == collectionPath;
    final configFileName = isRoot ? 'collection.json' : 'folder.json';
    final configFile = File(p.join(parentPath, configFileName));

    // 3. READ & UPDATE JSON:
    try {
      Map<String, dynamic> data = {};
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        if (content.isNotEmpty) {
          data = jsonDecode(content);
        }
      }

      // We store the sort order in the 'seq' key (Standard practice)
      data['seq'] = newOrderNames;

      // 4. WRITE TO DISK:
      // Use JsonEncoder.withIndent for pretty printing so Git diffs look good
      const encoder = JsonEncoder.withIndent('  ');
      await configFile.writeAsString(encoder.convert(data));
    } catch (e) {
      // If save fails, we might want to revert the state or show error
      print("Failed to save order: $e");
      // Optionally reload from disk to revert the UI
      ref.invalidateSelf();
    }
  }

  Future<void> handleDrop({
    required FileNode movedNode,
    required FileNode targetNode,
    required DropSlot slot,
  }) async {
    // 1. Identify Source and Destination Paths
    final String sourcePath = movedNode.path;
    final String sourceDir = p.dirname(sourcePath);
    String destDir;

    // 2. Determine where the file physically goes
    if (slot == DropSlot.center) {
      // Moving INTO the target folder
      destDir = targetNode.path;
    } else {
      // Moving NEXT TO the target (Same parent as target)
      destDir = p.dirname(targetNode.path);
    }

    // 3. Move the file physically (if folders are different)
    String newPath = sourcePath; // Default to current
    if (sourceDir != destDir) {
      final fileName = p.basename(sourcePath);
      newPath = p.join(destDir, fileName);

      // Rename/Move file
      if (movedNode.isDirectory) {
        final isActive = ref
            .read(activeReqProvider.notifier)
            .isDirectoryOpen(movedNode.path);
        await Directory(sourcePath).rename(newPath);
        if (isActive) {
          final prvSelectedPath = ref.read(activeReqProvider)!.path;
          final relativePath = p.relative(
            prvSelectedPath,
            from: movedNode.path,
          );
          final updatedActivePath = p.join(newPath, relativePath);
          // Update active node path if it was the moved folder
          ref
              .read(activeReqProvider.notifier)
              .setActiveNode(
                FileNode(
                  path: updatedActivePath,
                  name: p.basename(updatedActivePath),
                  type: NodeType.request,
                ),
              );
        }
      } else {
        final isActive = ref.read(activeReqProvider) == movedNode;
        debugPrint(
          "Moving file. Is active: $isActive, from $sourcePath to $newPath",
        );
        await File(sourcePath).rename(newPath);
        if (isActive) {
          // Update active node path if it was the moved file
          ref
              .read(activeReqProvider.notifier)
              .setActiveNode(
                FileNode(
                  path: newPath,
                  name: p.basename(newPath),
                  type: NodeType.request,
                ),
              );
        }
      }
    }

    // 4. Update the Sorting Sequence in 'folder.json' or 'collection.json'
    await _updateSortOrder(
      dirPath: destDir,
      movedName: p.basename(newPath),
      targetName: p.basename(targetNode.path),
      slot: slot,
    );

    // 5. Refresh Tree
    ref.invalidateSelf();
  }

  Future<void> _updateSortOrder({
    required String dirPath,
    required String movedName,
    required String targetName,
    required DropSlot slot,
  }) async {
    // A. Read existing config
    final isRoot = dirPath == collectionPath;
    final configFile = File(
      p.join(dirPath, isRoot ? 'collection.json' : 'folder.json'),
    );

    Map<String, dynamic> data = {};
    if (await configFile.exists()) {
      try {
        data = jsonDecode(await configFile.readAsString());
      } catch (e) {
        /* ignore */
      }
    }

    // B. Get current sequence or create one from file list if missing
    List<String> seq = [];
    if (data['seq'] != null) {
      seq = List<String>.from(data['seq']);
    } else {
      // If seq doesn't exist, we should probably populate it with current files
      // to avoid weird jumping, but for now let's start empty or rely on current load.
      // A robust app would list the directory here to init the seq.
    }

    // C. Remove moved item from old position (if it was there)
    seq.remove(movedName);

    // D. Insert at new position
    if (slot == DropSlot.center) {
      // If dropped inside a folder, we usually just append to the END of that folder's list
      // But here we are editing the PARENT's list.
      // Wait: If DropSlot.center, we moved the file INTO target.
      // We need to update TARGET'S folder.json, not the parent's.

      // So if slot is center, we are done with this level (step 3 handled the move).
      // We just need to add it to the Target's seq (optional, usually "append to bottom" is default).
      final targetConfigFile = File(p.join(dirPath, 'folder.json'));
      // ... Logic to append to target's seq if you want strict ordering inside too ...
      return;
    }

    // Handle Top/Bottom (Reordering within same level)
    int targetIndex = seq.indexOf(targetName);

    // If target isn't in seq yet (legacy folder), add it
    if (targetIndex == -1) {
      seq.add(targetName);
      targetIndex = seq.length - 1;
    }

    if (slot == DropSlot.top) {
      seq.insert(targetIndex, movedName);
    } else {
      // DropSlot.bottom
      seq.insert(targetIndex + 1, movedName);
    }

    // E. Save
    data['seq'] = seq;
    const encoder = JsonEncoder.withIndent('  ');
    await configFile.writeAsString(encoder.convert(data));
  }

  // --- Actions ---
  Future<void> createCollection(String name) async {
    if (collectionPath.isEmpty) return;
    await createFolder(collectionPath, name);
  }

  // ... (Your existing createFolder, createRequest, moveNode methods go here)
  Future<void> createFolder(String? parentPath, String folderName) async {
    final newPath = p.join(parentPath ?? collectionPath, folderName);
    await Directory(newPath).create();
    // Create the "Shadow Config" file
    await File(
      p.join(newPath, 'folder.json'),
    ).writeAsString('{"name": "$folderName"}');
    ref.invalidateSelf();
  }

  Future<void> createRequest(String? parentPath, String fileName) async {
    final safeName = fileName.endsWith('.json') ? fileName : '$fileName.json';
    final newPath = p.join(parentPath ?? collectionPath, safeName);
    await File(newPath).writeAsString('{"method": "GET", "url": ""}');
    ref
        .read(activeReqProvider.notifier)
        .setActiveNode(
          FileNode(path: newPath, name: safeName, type: NodeType.request),
        );
    ref.invalidateSelf();
  }

  Future<void> deleteNode(FileNode node) async {
    if (node.isDirectory) {
      await Directory(node.path).delete(recursive: true);
    } else {
      await File(node.path).delete();
    }
    ref.invalidateSelf();
  }

  Future<void> moveNode(String sourcePath, String targetParentPath) async {
    final fileName = p.basename(sourcePath);
    final destination = p.join(targetParentPath, fileName);

    if (sourcePath == destination) return;

    await FileSystemEntity.isDirectory(sourcePath).then((isDir) {
      if (isDir) {
        return Directory(sourcePath).rename(destination);
      } else {
        return File(sourcePath).rename(destination);
      }
    });

    ref.invalidateSelf();
  }

  Future<void> duplicateNode(FileNode node) async {
    await copyTo(node.path, p.dirname(node.path));
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

    ref.invalidateSelf();
  }
}

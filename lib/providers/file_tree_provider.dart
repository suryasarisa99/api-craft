import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/repository/storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// Configuration Provider (Database vs FileSystem)
enum StorageMode { filesystem, database }

final storageModeProvider = StateProvider<StorageMode>(
  (ref) => StorageMode.filesystem,
);

final fileTreeProvider =
    AsyncNotifierProvider<FileTreeNotifier, List<FileNode>>(
      FileTreeNotifier.new,
    );

class FileTreeNotifier extends AsyncNotifier<List<FileNode>> {
  Future<StorageRepository> get _repo => ref.read(repositoryProvider.future);
  ActiveReqNotifier get _activeReqNotifier =>
      ref.read(activeReqProvider.notifier);

  @override
  Future<List<FileNode>> build() async {
    // 1. Await the Repository (This links the loading states)
    // If repo is loading, this provider will also be in loading state.
    final repo = await ref.watch(repositoryProvider.future);

    // return _loadRecursive(repo, null);
    final nodes = await _loadRecursiveLinking(repo, null, null);
    _activeReqNotifier.hydrateWithTree(nodes);
    return nodes;
  }

  Future<List<FileNode>> _loadRecursive(
    StorageRepository repo,
    String? parentId,
  ) async {
    final nodes = await repo.getContents(parentId);
    List<FileNode> populatedNodes = [];
    for (var node in nodes) {
      if (node.isDirectory) {
        populatedNodes.add(
          FileNode(
            id: node.id,
            parentId: node.parentId,
            name: node.name,
            type: node.type,
            children: await _loadRecursive(repo, node.id),
          ),
        );
      } else {
        populatedNodes.add(node);
      }
    }
    return populatedNodes;
  }

  Future<List<FileNode>> _loadRecursiveLinking(
    StorageRepository repo,
    String? parentId,
    FileNode? parentObject,
  ) async {
    final nodes = await repo.getContents(parentId);

    List<FileNode> populatedNodes = [];

    for (var node in nodes) {
      node.parent = parentObject;
      if (node.isDirectory) {
        final children = await _loadRecursiveLinking(repo, node.id, node);
        populatedNodes.add(node..children = children);
      } else {
        populatedNodes.add(node);
      }
    }
    return populatedNodes;
  }

  // --- ACTIONS ---

  Future<void> createItem(String? parentId, String name, NodeType type) async {
    final repo = await _repo;
    await repo.createItem(parentId: parentId, name: name, type: type);
    ref.invalidateSelf();
  }

  Future<void> duplicateNode(FileNode node) async {
    final repo = await _repo;
    await repo.duplicateItem(node.id);
    ref.invalidateSelf();
  }

  Future<void> deleteNode(FileNode node) async {
    final repo = await _repo;
    await repo.deleteItem(node.id);
    // If active request was deleted, clear it
    final active = ref.read(activeReqProvider);
    if (active != null && active.id == node.id) {
      _activeReqNotifier.setActiveNode(null);
    }
    ref.invalidateSelf();
  }

  Future<void> renameNode(FileNode node, String newName) async {
    // 1. Execute Rename in Repo
    final repo = await _repo;
    final newId = await repo.renameItem(node.id, newName);

    // 2. Handle ID Change (Vital for FileSystem)
    if (newId != null && newId != node.id) {
      // _activeReqNotifier.onPathChanged(
      //   oldPath: node.id,
      //   newPath: newId,
      //   isDirectory: node.isDirectory,
      // );
    }

    ref.invalidateSelf();
  }
  // file_tree_notifier.dart

  Future<void> handleDrop({
    required FileNode movedNode,
    required FileNode targetNode,
    required DropSlot slot,
  }) async {
    final repo = await _repo;

    // 1. Determine Target Parent
    String? newParentId;
    if (slot == DropSlot.center && targetNode.isDirectory) {
      newParentId = targetNode.id;
    } else {
      newParentId = targetNode.parentId;
    }

    // 2. Move Item (Database or FileSystem move)
    // If FileSystem: 'finalId' will be the NEW path.
    // If Database: 'finalId' will be the SAME uuid.
    final resultId = await repo.moveItem(movedNode.id, newParentId);
    final finalId = resultId ?? movedNode.id;

    // 3. Handle Active Request Path Update (Ripple Effect)
    // If the ID changed (fs move), we must update the active tab if it matches.
    if (finalId != movedNode.id) {
      // _activeReqNotifier.onPathChanged(
      //   oldPath: movedNode.id,
      //   newPath: finalId,
      //   isDirectory: movedNode.isDirectory,
      // );
    }

    // 4. Update Sort Order (Only if reordering within a list)
    if (slot != DropSlot.center) {
      // A. Fetch the fresh list of the destination folder
      // We use the NEW parent ID here.
      final siblings = await repo.getContents(newParentId);

      // B. Convert to a mutable list of IDs
      // This ensures we are working with the definitive keys required by the Repo
      final List<String> orderedIds = siblings.map((e) => e.id).toList();

      // C. Remove the moved node if it exists (e.g. reordering within same folder)
      // We check for both old ID and new ID to be safe
      orderedIds.remove(movedNode.id);
      orderedIds.remove(finalId);

      // D. Find Insertion Index
      // We look for the targetNode.
      // Note: If targetNode was also moved in this operation (rare race condition),
      // this index might be -1, so we default to end.
      int targetIndex = orderedIds.indexOf(targetNode.id);
      if (targetIndex == -1) targetIndex = orderedIds.length;

      // E. Insert at correct slot
      if (slot == DropSlot.top) {
        orderedIds.insert(targetIndex, finalId);
      } else {
        // DropSlot.bottom
        // If target is at end, append. Else insert after.
        if (targetIndex + 1 >= orderedIds.length) {
          orderedIds.add(finalId);
        } else {
          orderedIds.insert(targetIndex + 1, finalId);
        }
      }

      // F. Save the new order
      await repo.saveSortOrder(newParentId, orderedIds);
    }

    // 5. Refresh UI
    ref.invalidateSelf();
  }
}

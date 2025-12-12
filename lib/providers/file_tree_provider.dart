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

class TreeData {
  final Map<String, Node> nodeMap;
  bool isLoading = true;
  TreeData(this.nodeMap, {this.isLoading = true});

  TreeData copyWith({Map<String, Node>? nodeMap, bool? isLoading}) {
    return TreeData(
      nodeMap ?? this.nodeMap,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final fileTreeProvider = NotifierProvider<FileTreeNotifier, TreeData>(
  FileTreeNotifier.new,
);

class FileTreeNotifier extends Notifier<TreeData> {
  StorageRepository get _repo => ref.read(repositoryProvider);
  ActiveReqIdNotifier get _activeReqNotifier =>
      ref.read(activeReqIdProvider.notifier);

  @override
  TreeData build() {
    _loadInitialData();

    // 2. Return initial state: empty map, isLoading: true
    return TreeData({});
  }

  // --- INITIAL LOAD ---

  Future<void> _loadInitialData() async {
    try {
      final repo = ref.read(repositoryProvider);
      final nodes = await repo.getNodes(); // List<Node>

      // 1. Build map
      final map = <String, Node>{};
      for (final n in nodes) {
        map[n.id] = n;
      }

      // 2. Link children → parent (FolderNode.children)
      for (final n in nodes) {
        final parentId = n.parentId;
        if (parentId == null) continue;

        var parent = map[parentId];
        if (parent is FolderNode) {
          parent = parent.copyWith(children: [...parent.children, n.id]);
          map[parentId] = parent;
        }
      }

      // 3. Commit
      state = TreeData(map, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Map<String, Node> get map => state.nodeMap;

  // The helper needs to handle both the item addition AND the state commit.
  void _addItem(Node item) {
    map[item.id] = item;
    // If no parent, just commit
    if (item.parentId == null) {
      state = state.copyWith(nodeMap: map);
      return;
    }

    _updateParent(
      parentId: item.parentId!,
      updateFn: (parent) {
        return parent.copyWith(children: [...parent.children, item.id]);
      },
    );
  }

  // Helper to update parent and commit the final state
  void _updateParent({
    required String? parentId,
    required FolderNode Function(FolderNode parent) updateFn,
  }) {
    final parent = map[parentId];

    if (parentId == null || parent == null || parent is! FolderNode) {
      state = state.copyWith(nodeMap: Map<String, Node>.from(map));
      return;
    }

    final updatedParent = updateFn(parent);
    map[parentId] = updatedParent;
    state = state.copyWith(nodeMap: map);
  }

  void updateNode(Node node) {
    final newMap = Map<String, Node>.from(map);
    newMap[node.id] = node;
    state = state.copyWith(nodeMap: newMap);
  }

  // --- ACTIONS ---

  Future<void> createItem(String? parentId, String name, NodeType type) async {
    if (state.isLoading) return;

    final id = await _repo.createItem(
      parentId: parentId,
      name: name,
      type: type,
    );
    late Node newItem;
    if (NodeType.folder == type) {
      newItem = FolderNode.fromMap({
        'id': id,
        'parent_id': parentId,
        'name': name,
        'children': [],
      });
    } else {
      newItem = RequestNode.fromMap({
        'id': id,
        'parent_id': parentId,
        'name': name,
      });
    }

    _addItem(newItem);
  }

  Future<void> duplicateNode(Node node) async {
    if (state.isLoading) return;

    final newId = await _repo.duplicateItem(node.id);
    final duplicatedNode = Node.fromMap({
      'id': newId,
      'parent_id': node.parentId,
      'name': '${node.name}_copy',
      'type': node.type.index,
    });

    _addItem(duplicatedNode);
  }

  List<Node> getChildrenNodes(FolderNode folder) {
    final children = <Node>[];
    for (final childId in folder.children) {
      final childNode = map[childId];
      if (childNode != null) {
        children.add(childNode);
        if (childNode is FolderNode) {
          children.addAll(getChildrenNodes(childNode));
        }
      }
    }
    return children;
  }

  List<String> getDeleteNodesIds(Node node) {
    if (node is RequestNode) {
      return [node.id];
    }
    return [node.id, ...getChildrenNodes(node as FolderNode).map((n) => n.id)];
  }

  Future<void> deleteNode(Node node) async {
    if (state.isLoading) return;
    final idsToDelete = getDeleteNodesIds(node);
    await _repo.deleteItems(idsToDelete);

    for (final id in idsToDelete) {
      map.remove(id);
    }

    _updateParent(
      parentId: node.parentId,
      updateFn: (parent) {
        final newChildrenIds = parent.children
            .where((id) => id != node.id)
            .toList();
        return parent.copyWith(children: newChildrenIds);
      },
    );
    // 3. Clear active request if needed
    final activeId = ref.read(activeReqIdProvider);
    if (activeId != null && activeId == node.id) {
      _activeReqNotifier.setActiveNode(null);
    }
  }

  Future<void> renameNode(Node node, String newName) async {
    await _repo.renameItem(node.id, newName);

    final currentMap = map;
    if (currentMap.isEmpty) return;

    // Update the single node in the map
    final newMap = Map<String, Node>.from(currentMap);
    newMap[node.id] = node.copyWith(name: newName);

    // Commit the new state
    state = state.copyWith(nodeMap: newMap);
  }

  // The handleDrop logic remains complex and should either return affected nodes from repo
  // or be handled by a full refresh, but the pattern is now clear: update repo, then commit state.
  Future<void> handleDrop({
    required Node movedNode,
    required Node targetNode,
    required DropSlot slot,
  }) async {
    // ... repository calls ...

    // The safest approach for this complex operation:
    // 1. Perform complex repo updates
    // 2. Refresh the entire node map from the repo (like the AsyncNotifier build() did)
    // 3. Commit the new state
    final nodes = await _repo.getNodes();
    final Map<String, Node> nodeMap = {for (var node in nodes) node.id: node};
    state = state.copyWith(nodeMap: nodeMap);
  }
}

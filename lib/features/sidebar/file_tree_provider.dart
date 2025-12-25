import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// Configuration Provider (Database vs FileSystem)
enum StorageMode { filesystem, database }

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

  Map<String, Node> get map => state.nodeMap;

  @override
  TreeData build() {
    ref.watch(selectedCollectionProvider.select((c) => c?.id));
    debugPrint("building file tree");
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

  // --- HYDRATION ---
  Future<void> hydrateNode(String id) async {
    final node = map[id];
    if (node == null) return;
    if (node.config.isDetailLoaded) return; // Already loaded
    debugPrint("Hydrating node ${node.name}");
    try {
      final details = await _repo.getNodeDetails(id);
      if (details.isNotEmpty) {
        // Hydrate modifies the config object inside the node IN PLACE
        // BUT for Riverpod to react, we might need to trigger an update if we were completely immutable.
        // However, our Node.hydrate modifies existing config ref? No, let's look at Node.hydrate.
        // Actually Node.hydrate updates properties of config.
        // To play nice with Riverpod, we should probably treat it as a state change.
        node.hydrate(details);
        // Force state update to notify listeners
        state = state.copyWith(nodeMap: Map.from(map));
      }
    } catch (e) {
      debugPrint("Error hydrating node $id: $e");
    }
  }

  Future<void> updateNode(Node node) async {
    final newMap = Map<String, Node>.from(map);
    newMap[node.id] = node;
    state = state.copyWith(nodeMap: newMap);

    // Persist
    await _repo.updateNode(node);
  }

  // --- Granular Updates ---

  void updateNodeName(String id, String name) {
    final node = map[id];
    if (node != null) updateNode(node.copyWith(name: name));
  }

  void updateRequestMethod(String id, String method) {
    final node = map[id];
    if (node is RequestNode) updateNode(node.copyWith(method: method));
  }

  void updateRequestUrl(String id, String url) {
    final node = map[id];
    if (node is RequestNode) updateNode(node.copyWith(url: url));
  }

  void updateNodeDescription(String id, String description) {
    final node = map[id];
    if (node != null) {
      updateNode(
        node.copyWith(config: node.config.copyWith(description: description)),
      );
    }
  }

  void updateNodeHeaders(String id, List<KeyValueItem> headers) {
    final node = map[id];
    if (node != null) {
      updateNode(node.copyWith(config: node.config.copyWith(headers: headers)));
    }
  }

  void updateRequestQueryParameters(String id, List<KeyValueItem> params) {
    final node = map[id];
    if (node is RequestNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(queryParameters: params)),
      );
    }
  }

  void updateRequestScripts(String id, String scripts) {
    final node = map[id];
    if (node is RequestNode) {
      // Scripts also need separate repo call if stored separately?
      // updateNode handles node persistence which includes config.
      // But ReqComposeProvider had `_repo.updateScripts`.
      // Node.toMap usually includes scripts.
      // Let's assume updateNode handles it, but previous code had specific call.
      // I will trust updateNode does it (NodeConfig handles it).
      updateNode(node.copyWith(config: node.config.copyWith(scripts: scripts)));
      // If we need optimized partial update we can add it later.
    }
  }

  void updateRequestBodyType(String id, String? type) {
    final node = map[id];
    if (node is RequestNode) {
      var headers = List<KeyValueItem>.from(node.config.headers);
      headers.removeWhere((h) => h.key.toLowerCase() == 'content-type');

      if (type != null) {
        String? contentType;
        switch (type) {
          case 'json':
            contentType = 'application/json';
            break;
          case 'xml':
            contentType = 'application/xml';
            break;
          case 'html':
            contentType = 'text/html';
            break;
          case 'text':
            contentType = 'text/plain';
            break;
          case 'form-urlencoded':
            contentType = 'application/x-www-form-urlencoded';
            break;
          case 'multipart-form-data':
            contentType = 'multipart/form-data';
            break;
        }

        if (contentType != null) {
          headers.add(KeyValueItem(key: 'Content-Type', value: contentType));
        }
      }

      updateNode(
        node.copyWith(
          config: node.config.copyWith(bodyType: type, headers: headers),
        ),
      );
    }
  }

  void updateNodeAuth(String id, AuthData auth) {
    final node = map[id];
    if (node != null) {
      updateNode(node.copyWith(config: node.config.copyWith(auth: auth)));
    }
  }

  void updateFolderVariables(String id, List<KeyValueItem> variables) {
    final node = map[id];
    if (node is FolderNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(variables: variables)),
      );
    }
  }

  void updateRequestStatusCode(String id, int statusCode) {
    final node = map[id];
    if (node is RequestNode) {
      updateNode(node.copyWith(statusCode: statusCode));
    }
  }

  // uses vs code like multiple folder creations by using `/`
  Future<void> createItem(
    String? parentId,
    String name,
    NodeType type, {
    RequestType requestType = RequestType.http,
  }) async {
    if (state.isLoading) return;

    final methodStr = (type == NodeType.request)
        ? requestType == RequestType.ws
              ? 'WS'
              : 'GET'
        : null;

    final folderNames = name
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    String? fileName;
    if (NodeType.request == type) {
      // remove last item in foldersNames, its a fileName
      fileName = folderNames.removeLast();
    }

    final List<Node> nodes = [];
    final uuid = Uuid();

    final ids = folderNames.map((e) => uuid.v4()).toList();
    final childId = fileName == null ? null : uuid.v4();
    debugPrint(ids.toString());
    for (int i = 0; i < folderNames.length; i++) {
      nodes.add(
        FolderNode(
          id: ids[i],
          parentId: i == 0 ? parentId : ids[i - 1],
          children: i < folderNames.length - 1
              ? [ids[i + 1]]
              : childId == null
              ? []
              : [childId],
          name: folderNames[i],
          config: FolderNodeConfig(),
          sortOrder: 0,
        ),
      );
    }
    if (fileName != null) {
      nodes.add(
        RequestNode(
          id: childId!,
          parentId: ids.lastOrNull ?? parentId,
          name: fileName,
          requestType: requestType,
          method: methodStr!,
          statusCode: null,
          sortOrder: 0,
          config: RequestNodeConfig(queryParameters: []),
        ),
      );
    }

    await _repo.createMany(nodes);

    // direct mutation
    for (final node in nodes) {
      state.nodeMap[node.id] = node;
    }
    // it commits the state
    _addItem(nodes.first);
  }

  Future<void> duplicateNode(Node node) async {
    if (node is FolderNode) {
      await duplicateFolder(node);
    } else {
      final duplicatedNode = node.copyWith(
        id: const Uuid().v4(),
        name: '${node.name}_copy',
        config: node.config.clone(),
      );
      debugPrint(
        "headers: ${duplicatedNode.config.headers.length}, original: ${node.config.headers.length}",
      );
      await _repo.createOne(duplicatedNode);
      _addItem(duplicatedNode);
    }
  }

  Future<void> duplicateFolder(FolderNode node) async {
    final allNodes = [
      node,
      ...getChildrenNodes(node),
    ]; // includes the folder itself
    final idMap = <String, String>{}; // oldId → newId

    // 1. Generate all new IDs first
    for (final n in allNodes) {
      idMap[n.id] = const Uuid().v4();
    }

    // 2. Rebuild nodes with new IDs + fixed parentId
    final duplicated = <Node>[];

    for (final n in allNodes) {
      final newId = idMap[n.id]!;

      /* fixes for copying subfolder
      - when copying a subfolder, its parentId is not null, but the parentId is not in idMap.
      - so we use ?? to fallback to the actual parentId. so new copy folder created in the same parent.
      */
      final newParentId = n.parentId == null
          ? null
          : idMap[n.parentId] ?? n.parentId;

      if (n is FolderNode) {
        duplicated.add(
          n.copyWith(
            id: newId,
            parentId: newParentId,
            children: n.children.map((cid) => idMap[cid]!).toList(),
            config: n.config.clone(),
          ),
        );
      } else {
        duplicated.add(n.copyWith(id: newId, parentId: newParentId));
      }
    }
    duplicated[0] = duplicated[0].copyWith(name: '${node.name}_copy');

    // 3. Insert duplicated nodes into map
    for (final n in duplicated) {
      map[n.id] = n;
    }

    // 4. Add duplicated root folder to its parent
    final originalParent = node.parentId;
    if (originalParent != null) {
      final parent = map[originalParent];
      if (parent is FolderNode) {
        final updatedParent = parent.copyWith(
          children: [...parent.children, idMap[node.id]!],
        );
        map[originalParent] = updatedParent;
      }
    }
    await _repo.createMany(duplicated);
    // 5. Commit
    state = state.copyWith(nodeMap: map);
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
      _activeReqNotifier.setActiveId(null);
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

  Future<void> handleDrop({
    required Node movedNode,
    required Node targetNode,
    required DropSlot slot,
  }) async {
    // 1. Determine Target Parent ID
    String? newParentId;
    if (slot == DropSlot.center && targetNode is FolderNode) {
      newParentId = targetNode.id;
    } else {
      newParentId = targetNode.parentId;
    }

    // 2. Repo Update (Move)
    await _repo.moveItem(movedNode.id, newParentId);

    // 3. Prepare Local State
    final currentMap = state.nodeMap;
    final newMap = Map<String, Node>.from(currentMap);

    // --- A. REMOVE FROM OLD PARENT ---
    if (movedNode.parentId != null && newMap.containsKey(movedNode.parentId)) {
      final oldParent = newMap[movedNode.parentId] as FolderNode;
      final updatedOldChildren = oldParent.children
          .where((id) => id != movedNode.id)
          .toList();
      newMap[movedNode.parentId!] = oldParent.copyWith(
        children: updatedOldChildren,
      );
    }

    // --- B. UPDATE MOVED NODE PARENT POINTER (DO THIS FIRST) ---
    // Update the map immediately so subsequent lookups see the correct Parent ID
    if (newMap.containsKey(movedNode.id)) {
      newMap[movedNode.id] = newMap[movedNode.id]!.copyWith(
        parentId: newParentId,
        forceNullParent: newParentId == null,
      );
    }

    // --- C. CALCULATE & APPLY NEW ORDER ---
    List<String> newOrderIds = [];

    if (newParentId != null) {
      // CASE 1: MOVING INTO A FOLDER
      if (newMap.containsKey(newParentId)) {
        final newParent = newMap[newParentId] as FolderNode;
        newOrderIds = List<String>.from(newParent.children);
        newOrderIds.remove(movedNode.id);
        _insertAtSlot(newOrderIds, movedNode.id, targetNode.id, slot);

        // Update Parent
        newMap[newParentId] = newParent.copyWith(children: newOrderIds);
      }
    } else {
      // CASE 2: MOVING TO ROOT
      final rootNodes = newMap.values.where((n) => n.parentId == null).toList();

      // Ensure we start with current visual order
      rootNodes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      newOrderIds = rootNodes.map((n) => n.id).toList();
      newOrderIds.remove(movedNode.id);
      _insertAtSlot(newOrderIds, movedNode.id, targetNode.id, slot);
    }

    // --- D. CRITICAL: UPDATE SORT ORDER (DO THIS LAST) ---
    // This loop must run LAST. It iterates over the final list of IDs
    // and stamps the index (0, 1, 2...) onto the Node objects in the Map.
    for (int i = 0; i < newOrderIds.length; i++) {
      final id = newOrderIds[i];
      if (newMap.containsKey(id)) {
        // We use newMap[id]! to ensure we get the version
        // that already has the updated parentId (from Step B).
        newMap[id] = newMap[id]!.copyWith(sortOrder: i);
      }
    }

    // 4. Commit State
    state = state.copyWith(nodeMap: newMap);

    // to trigger inheritance if parent changes
    // not part of reorder logic.

    // 5. Persist Sort Order
    await _repo.saveSortOrder(newParentId, newOrderIds);

    if (movedNode is FolderNode) {
      debugPrint(
        "triggering node update for folder move for: ${movedNode.name}",
      );
      ref
          .read(nodeUpdateTriggerProvider.notifier)
          .setLastUpdatedFolder(movedNode.id);
    }
  }

  // Helper to keep the insertion logic DRY
  void _insertAtSlot(
    List<String> list,
    String movedId,
    String targetId,
    DropSlot slot,
  ) {
    if (slot == DropSlot.center) {
      list.add(movedId);
    } else {
      int index = list.indexOf(targetId);
      if (index == -1) index = list.length;

      if (slot == DropSlot.top) {
        list.insert(index, movedId);
      } else {
        if (index + 1 >= list.length) {
          list.add(movedId);
        } else {
          list.insert(index + 1, movedId);
        }
      }
    }
  }
}

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/providers/ref_provider.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/features/request/services/http_service.dart';
import 'package:api_craft/features/sidebar/providers/clipboard_provider.dart';
import 'package:api_craft/features/request/widgets/tabs/tab_titles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoid/nanoid.dart';

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

final groupDebouncer = GroupedDebouncer(Duration(milliseconds: 300));

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
  // --- INITIAL LOAD ---
  Future<void> _loadInitialData() async {
    try {
      final collection = ref.read(selectedCollectionProvider);
      if (collection == null) return;

      final repo = ref.read(repositoryProvider);
      final nodes = await repo.getNodes(); // List<Node>

      // 1. Build map
      final map = <String, Node>{};

      // Find persisted Root Node (FolderNode with id == collection.id)
      final persistedRootIndex = nodes.indexWhere((n) => n.id == collection.id);
      FolderNodeConfig rootConfig;
      if (persistedRootIndex != -1) {
        final persistedRoot = nodes[persistedRootIndex];
        // Use its config. If it's a FolderNode, we cast.
        // It SHOULD be a FolderNode.
        if (persistedRoot is FolderNode) {
          rootConfig = persistedRoot.config;
        } else {
          // Fallback if type mismatch (rare)
          rootConfig = FolderNodeConfig(isDetailLoaded: true);
        }
        // Remove from list so we don't duplicate processing (though map handles overlaps)
        // nodes.removeAt(persistedRootIndex); // List is immutable? No usually list<Node>
      } else {
        // Fallback: Create default config if not found
        rootConfig = FolderNodeConfig(isDetailLoaded: true);
      }

      // Inject Root Collection Node
      final rootNode = CollectionNode(
        collection: collection,
        config: rootConfig,
        children: [],
      );
      map[collection.id] = rootNode;

      for (final n in nodes) {
        if (n.id == collection.id) {
          // Already handled as rootNode, but we need its children info?
          // The persisted node has 'children' ids if it was a FolderNode.
          // But our loop "Link children -> parent" (step 2) rebuilds children list dynamically from parentIds.
          // The persisted 'children' list in FolderNode is strictly for ORDER.
          // FileTreeProvider recalculates children based on parentId for structure, but SORT ORDER?
          // Wait, 'children' list in FolderNode usually persists the ORDER.
          // This provider sets children dynamically in Step 2.
          // Does Step 2 preserve order?
          // Step 2 just appends: `parent.copyWith(children: [...parent.children, n.id])`.
          // If valid sort order exists, we should use it?
          // Currently Step 2 ignores persisted 'children' list?
          // Let's look at Step 2.
          continue;
        }

        if (n.parentId == null) {
          // Reparent top-level nodes to Collection
          map[n.id] = n.copyWith(parentId: collection.id);
        } else {
          map[n.id] = n;
        }
      }

      // 2. Link children → parent (FolderNode.children)
      // We iterate map.values to see the modified parentIds
      final allNodes = map.values.toList();
      for (final n in allNodes) {
        if (n.id == collection.id) continue;

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
      debugPrint("Error loading tree: $e");
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

  Future<void> updateNode(Node node, {bool persist = false}) async {
    final newMap = Map<String, Node>.from(map);
    newMap[node.id] = node;
    state = state.copyWith(nodeMap: newMap);

    // Persistance: it is done by request ,folder config dialog with debounce / lazily when folder closes
    if (persist) {
      groupDebouncer.run(node.id, () {
        _repo.updateNode(node);
      });
    }
  }

  // --- Granular Updates ---

  void updateNodeName(String id, String name) {
    final node = map[id];
    if (node != null) updateNode(node.copyWith(name: name));
  }

  void updateRequestMethod(String id, String method, {bool persist = false}) {
    final node = map[id];
    if (node is RequestNode) {
      updateNode(node.copyWith(method: method), persist: persist);
    }
  }

  void updateUrl(String id, String url, {bool persist = false}) {
    final node = map[id];
    if (node is RequestNode) updateNode(node.copyWith(url: url));
  }

  void updateDescription(
    String id,
    String description, {
    bool persist = false,
  }) {
    final node = map[id];
    if (node != null) {
      updateNode(
        node.copyWith(config: node.config.copyWith(description: description)),
      );
    }
  }

  void updateHeaders(
    String id,
    List<KeyValueItem> headers, {
    bool persist = false,
  }) {
    final node = map[id];
    if (node != null) {
      updateNode(
        node.copyWith(config: node.config.copyWith(headers: headers)),
        persist: persist,
      );
    }
  }

  void updateQueryParameters(
    String id,
    List<KeyValueItem> params, {
    bool persist = false,
  }) {
    final node = map[id];
    if (node is RequestNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(queryParameters: params)),
        persist: persist,
      );
    }
  }

  void updateTestScript(String id, String script, {bool persist = false}) {
    final node = map[id];
    if (node == null) return;

    if (node is RequestNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(testScript: script)),
        persist: persist,
      );
    } else if (node is FolderNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(testScript: script)),
        persist: persist,
      );
    }
  }

  void updatePreRequestScript(
    String id,
    String script, {
    bool persist = false,
  }) {
    final node = map[id];
    if (node == null) return;

    if (node is RequestNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(preRequestScript: script)),
        persist: persist,
      );
    } else if (node is FolderNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(preRequestScript: script)),
        persist: persist,
      );
    }
  }

  void updatePostRequestScript(
    String id,
    String script, {
    bool persist = false,
  }) {
    final node = map[id];
    if (node == null) return;

    if (node is RequestNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(postRequestScript: script)),
        persist: persist,
      );
    } else if (node is FolderNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(postRequestScript: script)),
        persist: persist,
      );
    }
  }

  void updateRequestBodyType(String id, String? type, {bool persist = false}) {
    final node = map[id];
    if (node is RequestNode) {
      var headers = List<KeyValueItem>.from(node.config.headers);
      headers.removeWhere((h) => h.key.toLowerCase() == 'content-type');

      if (type != null) {
        String? contentType = switch (type) {
          BodyType.json || BodyType.graphql => 'application/json',
          BodyType.xml => 'application/xml',
          BodyType.text => 'text/plain',
          BodyType.formUrlEncoded => 'application/x-www-form-urlencoded',
          BodyType.formMultipart => 'multipart/form-data',
          _ => null,
        };

        if (contentType != null) {
          headers.add(KeyValueItem(key: 'Content-Type', value: contentType));
        }
      }

      updateNode(
        node.copyWith(
          config: node.config.copyWith(bodyType: type, headers: headers),
        ),
        persist: persist,
      );
    }
  }

  // void updateAuth(String id, AuthData auth, {bool persist = false}) {
  //   final node = map[id];
  //   if (node != null) {
  //     updateNode(
  //       node.copyWith(config: node.config.copyWith(auth: auth)),
  //       persist: persist,
  //     );
  //   }
  // }

  // Auth
  void setAuthData(
    String id,
    AuthType authType,
    Map<String, dynamic> data, {
    bool persist = false,
  }) {
    final node = state.nodeMap[id]!;
    updateNode(
      node.copyWith(
        config: node.config.copyWith(
          auth: AuthData(type: authType, data: data),
        ),
      ),
      persist: persist,
    );
  }

  void setAuthType(String id, AuthType authType, {bool persist = false}) {
    //resets data
    final node = state.nodeMap[id]!;
    updateNode(
      node.copyWith(
        config: node.config.copyWith(auth: AuthData(type: authType)),
      ),
      persist: persist,
    );
  }

  void updateFolderVariables(
    String id,
    List<KeyValueItem> variables, {
    bool persist = false,
  }) {
    final node = map[id];
    if (node is FolderNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(variables: variables)),
        persist: persist,
      );
    }
  }

  void updateAssertions(
    String id,
    List<AssertionDefinition> assertions, {
    bool persist = false,
  }) {
    final node = map[id];
    if (node == null) return;

    // Both Request and Folder can have assertions if we extended FolderNode to support it fully in UI,
    // but primarily RequestNode for now according to requirements.
    // However, NodeConfig has assertions, so both support it.

    if (node is RequestNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(assertions: assertions)),
        persist: persist,
      );
    } else if (node is FolderNode) {
      updateNode(
        node.copyWith(config: node.config.copyWith(assertions: assertions)),
        persist: persist,
      );
    }
  }

  void updateEncryptionKey(String id, String key) {
    final node = map[id];
    if (node is FolderNode) {
      final newConfig = node.config.clone()..encryptedKey = key;
      updateNode(
        node.copyWith(config: newConfig),
        persist: false, // Persistence already handled by service
      );
    }
  }

  void updateStatusCode(String id, int statusCode) {
    final node = map[id];
    if (node is RequestNode) {
      updateNode(node.copyWith(statusCode: statusCode));
    }
  }

  void updateHistoryId(String id, String? historyId) {
    final node = map[id];
    if (node is RequestNode) {
      updateNode(
        node.copyWith(
          config: node.config.copyWith(
            historyId: historyId,
            forceNullHistoryId: historyId == null,
          ),
        ),
      );
    }
    final repo = ref.read(repositoryProvider);
    repo.setHistoryIndex(id, historyId);
  }

  // uses vs code like multiple folder creations by using `/`
  Future<void> createItem(
    String? parentId,
    String name,
    NodeType type, {
    RequestType requestType = RequestType.http,
    String? bodyType,
  }) async {
    if (state.isLoading) return;

    final methodStr = (type == NodeType.request)
        ? requestType == RequestType.ws
              ? 'WS'
              : bodyType == BodyType.graphql
              ? 'POST'
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
    final ids = folderNames.map((e) => nanoid()).toList();
    final childId = fileName == null ? null : nanoid();
    debugPrint(ids.toString());
    // For creation, we default use parentId as is (local view)
    // But for DB, if parentId == collectionId, we must use null.
    final collectionId = ref.read(selectedCollectionProvider)?.id;

    for (int i = 0; i < folderNames.length; i++) {
      nodes.add(
        FolderNode(
          id: ids[i],
          parentId: i == 0 ? (parentId ?? collectionId) : ids[i - 1],
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
          parentId: ids.lastOrNull ?? (parentId ?? collectionId),
          name: fileName,
          requestType: requestType,

          method: methodStr!,
          statusCode: null,
          sortOrder: 0,
          config: RequestNodeConfig(
            queryParameters: [],
            headers: bodyType == BodyType.graphql
                ? [KeyValueItem(key: 'Content-Type', value: 'application/json')]
                : [],
            bodyType:
                bodyType ??
                (requestType == RequestType.ws
                    ? BodyType.text
                    : BodyType.noBody),
          ),
        ),
      );
    }

    // Prepare nodes for DB (translate parentId: collectionId -> null)
    final dbNodes = nodes.map((n) {
      if (n.parentId == collectionId) {
        return n.copyWith(parentId: null, forceNullParent: true);
      }
      return n;
    }).toList();

    await _repo.createMany(dbNodes);

    // direct mutation (Local View keeps collectionId as parent)
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
        id: nanoid(),
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
      ...getChildrenNodes(node, includeFolders: true),
    ]; // includes the folder itself
    final idMap = <String, String>{}; // oldId → newId

    // 1. Generate all new IDs first
    for (final n in allNodes) {
      idMap[n.id] = nanoid();
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

    // 4. Add duplicated root to parent if parent exists
    // Logic handles parentId creation in the loop, but we need to link parent -> child in map if parent exists.
    final rootDup = duplicated[0]; // The folder itself
    if (rootDup.parentId != null && map.containsKey(rootDup.parentId)) {
      _updateParent(
        parentId: rootDup.parentId!,
        updateFn: (p) => p.copyWith(children: [...p.children, rootDup.id]),
      );
    }

    // DB Translation
    final collectionId = ref.read(selectedCollectionProvider)?.id;
    final dbNodes = duplicated.map((n) {
      if (n.parentId == collectionId) {
        return n.copyWith(parentId: null, forceNullParent: true);
      }
      return n;
    }).toList();

    await _repo.createMany(dbNodes);

    // 5. Commit (Local View)
    for (final n in duplicated) {
      map[n.id] = n;
    }
    state = state.copyWith(nodeMap: map);
  }

  List<Node> getChildrenNodes(FolderNode folder, {bool includeFolders = true}) {
    final children = <Node>[];
    for (final childId in folder.children) {
      final childNode = map[childId];
      if (childNode != null) {
        if (childNode is FolderNode) {
          if (includeFolders) {
            children.add(childNode);
          }
          children.addAll(
            getChildrenNodes(childNode, includeFolders: includeFolders),
          );
        } else {
          children.add(childNode);
        }
      }
    }
    return children;
  }

  List<String> getRecursiveRequestIds(
    Set<String> nodeIds, {
    bool includeFolders = true,
  }) {
    final requestIds = <String>{};
    for (final id in nodeIds) {
      final node = map[id];
      if (node == null) continue;
      if (node is RequestNode) {
        requestIds.add(node.id);
      } else if (node is FolderNode) {
        final subIds = getChildrenNodes(
          node,
          includeFolders: includeFolders,
        ).map((n) => n.id);
        requestIds.addAll(includeFolders ? [node.id, ...subIds] : subIds);
      }
    }
    return requestIds.toList();
  }

  List<String> getRecursiveSelectedIds({bool includeFolders = true}) {
    final selected = ref.read(selectedNodesProvider);
    final selectedIds = selected.isNotEmpty
        ? selected
        : {ref.read(activeReqIdProvider)!};
    return getRecursiveRequestIds(selectedIds, includeFolders: includeFolders);
  }

  Future<void> runSelectedRequests(BuildContext context) async {
    final requestIds = getRecursiveSelectedIds(includeFolders: false);
    if (requestIds.isEmpty) return;
    final httpService = HttpService();
    // Sequential Execution
    final r = ref.read(refProvider); //to prevent circular dependency
    for (final reqId in requestIds) {
      try {
        httpService.run(r, reqId, context: context);
      } catch (e) {
        debugPrint("Error running request $reqId: $e");
      }
    }
  }

  Future<void> deleteSelectedNodes() async {
    await _deleteNodes(getRecursiveSelectedIds(includeFolders: true));
  }

  Future<void> _deleteNodes(List<String> nodeIds) async {
    // 1. Repo Delete
    await _repo.deleteItems(nodeIds);

    // 2. Local State Update
    // Let's identify unique parents of the Top-Level deleted nodes to minimize updates.
    // The `getDeleteNodesIds` returns the subtree. We only need to detach from parents of the roots of these subtrees.
    // But `nodeIds` might contain children of other nodes in `nodeIds`.
    // Smart logic: Only update parents of nodes whose parent is NOT being deleted.

    final currentMap = Map<String, Node>.from(state.nodeMap);
    final parentsToUpdate = <String>{};

    for (final id in nodeIds) {
      final node = currentMap[id];
      if (node != null && node.parentId != null) {
        // If parent is NOT in delete list, we must update it
        if (!nodeIds.contains(node.parentId)) {
          parentsToUpdate.add(node.parentId!);
        }
      }
      currentMap.remove(id);
    }

    state = state.copyWith(nodeMap: currentMap);

    // 4. Update Parents
    for (final pId in parentsToUpdate) {
      _updateParent(
        parentId: pId,
        updateFn: (parent) {
          final newChildren = parent.children
              .where((cId) => !nodeIds.contains(cId))
              .toList();
          return parent.copyWith(children: newChildren);
        },
      );
    }

    // 5. Clear active ID if deleted
    final activeId = ref.read(activeReqIdProvider);
    if (activeId != null && nodeIds.contains(activeId)) {
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
    final collectionId = ref.read(selectedCollectionProvider)?.id;
    final dbParentId = (newParentId == collectionId) ? null : newParentId;

    await _repo.moveItem(movedNode.id, dbParentId);

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

  Future<void> paste(ClipboardState clipboard, {String? targetId}) async {
    if (clipboard.isEmpty) return;

    final targetNode = targetId != null ? map[targetId] : null;

    // If target is a folder, paste INSIDE.
    // If target is a file, paste into its PARENT.
    // If target is null, paste to ROOT.
    String? destinationParentId;
    if (targetNode is FolderNode) {
      destinationParentId = targetId;
    } else if (targetNode != null) {
      destinationParentId = targetNode.parentId;
    }

    if (clipboard.action == ClipboardAction.copy) {
      // Loop and Duplicate
      for (final id in clipboard.nodeIds) {
        final node = map[id];
        if (node != null) {
          await _duplicateNodeToParent(node, destinationParentId);
        }
      }
    } else {
      // Move (Cut)
      // We must be careful about order if multiple items are moved.
      // And we must ensure we don't move a parent into its own child (cycle).
      // The cycle check is handled in handleDrop, but here we trust _moveNodeToParent?
      // _moveNodeToParent doesn't check cycles. We should add a check.

      for (final id in clipboard.nodeIds) {
        final node = map[id];
        if (node != null) {
          // Cycle check
          if (destinationParentId != null) {
            var ptr = map[destinationParentId];
            bool cycle = false;
            while (ptr != null) {
              if (ptr.id == node.id) {
                cycle = true;
                break;
              }
              ptr = map[ptr.parentId];
            }
            if (cycle) continue; // Skip moving parent into child
          }

          // 1. Repo Move
          await _repo.moveItem(node.id, destinationParentId);

          // 2. Local State Update
          await _moveNodeToParent(node, destinationParentId);
        }
      }
    }
    ref.read(clipboardProvider.notifier).clear();
  }

  Future<void> _duplicateNodeToParent(Node node, String? parentId) async {
    final collectionId = ref.read(selectedCollectionProvider)?.id;
    final effectiveParentId = parentId ?? collectionId;

    if (node is FolderNode) {
      await _duplicateFolderToParent(node, effectiveParentId);
    } else {
      final newNode = node.copyWith(
        id: nanoid(),
        parentId: effectiveParentId,
        forceNullParent: effectiveParentId == null,
        name: node
            .name, // Keep same name or add copy? VS Code keeps same name on copy-paste to other folder
        config: node.config.clone(),
      );
      final dbNode = (effectiveParentId == collectionId)
          ? newNode.copyWith(parentId: null, forceNullParent: true)
          : newNode;

      await _repo.createOne(dbNode);
      _addItem(newNode);
    }
  }

  Future<void> _duplicateFolderToParent(
    FolderNode node,
    String? targetParentId,
  ) async {
    final collectionId = ref.read(selectedCollectionProvider)?.id;
    final effectiveParentId = targetParentId ?? collectionId;

    final allNodes = [node, ...getChildrenNodes(node)];
    final idMap = <String, String>{};
    for (final n in allNodes) idMap[n.id] = nanoid();

    final duplicated = <Node>[];
    for (final n in allNodes) {
      final newId = idMap[n.id]!;
      // If it's the root being moved, use effectiveParentId.
      // Else calculate new parent based on idMap
      String? newParentId;
      if (n.id == node.id) {
        newParentId = effectiveParentId;
      } else {
        newParentId = n.parentId == null
            ? null
            : idMap[n.parentId] ?? n.parentId;
      }

      if (n is FolderNode) {
        duplicated.add(
          n.copyWith(
            id: newId,
            parentId: newParentId,
            forceNullParent: newParentId == null,
            children: n.children.map((c) => idMap[c]!).toList(),
            config: n.config.clone(),
          ),
        );
      } else {
        duplicated.add(
          n.copyWith(
            id: newId,
            parentId: newParentId,
            forceNullParent: newParentId == null,
            config: n.config.clone(),
          ),
        );
      }
    }

    // DB Translation for Folder Tree
    // We need to ensure root folder uses null parent for DB if it's top level
    final dbNodes = duplicated.map((n) {
      if (n.parentId == collectionId) {
        return n.copyWith(parentId: null, forceNullParent: true);
      }
      return n;
    }).toList();

    await _repo.createMany(dbNodes);

    // Update local state is tricky for bulk.
    // Easiest is to add them to map and update the parent of the root copy.
    for (final n in duplicated) map[n.id] = n;

    // Update destination parent to include the new root copy
    _updateParent(
      parentId: targetParentId,
      updateFn: (parent) =>
          parent.copyWith(children: [...parent.children, idMap[node.id]!]),
    );

    // Add to map (triggers commit if root)
    if (targetParentId == null) {
      state = state.copyWith(nodeMap: map);
    }
  }

  Future<void> _moveNodeToParent(Node node, String? newParentId) async {
    // 1. Remove from old parent
    if (node.parentId != null) {
      _updateParent(
        parentId: node.parentId,
        updateFn: (p) => p.copyWith(
          children: p.children.where((c) => c != node.id).toList(),
        ),
      );
    }

    // 2. Update Node self
    final updatedNode = node.copyWith(
      parentId: newParentId,
      forceNullParent: newParentId == null,
    );
    map[node.id] = updatedNode;

    // 3. Add to new parent
    if (newParentId != null) {
      _updateParent(
        parentId: newParentId,
        updateFn: (p) => p.copyWith(children: [...p.children, node.id]),
      );
    } else {
      // Moved to root, force refresh
      state = state.copyWith(nodeMap: map);
    }
  }
}

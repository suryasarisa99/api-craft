import 'package:api_craft/http/raw/raw_http_req.dart';
import 'package:api_craft/repository/storage_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';

final resolveConfigProvider = NotifierProvider.autoDispose
    .family<ResolveConfigNotifier, ResolveConfig, String>(
      ResolveConfigNotifier.new,
    );

// this wrapper to ensure we only rebuild if the Node ID changes,
// not if the Node object reference changes (since we are editing it).
class EditorParams {
  final Node node;
  const EditorParams(this.node);

  @override
  bool operator ==(Object other) =>
      other is EditorParams && other.node.id == node.id;

  @override
  int get hashCode => node.id.hashCode;
}

class ResolveConfigNotifier extends Notifier<ResolveConfig> {
  final String id;
  ResolveConfigNotifier(this.id);

  Node get getNode =>
      ref.read(fileTreeProvider.select((treeData) => treeData.nodeMap[id]!));

  late final StorageRepository _repo = ref.read(repositoryProvider);

  @override
  build() {
    final node = ref.read(
      fileTreeProvider.select((treeData) => treeData.nodeMap[id]!),
    );
    if (node is RequestNode) {
      // handles all non immediate parent position changes
      // handles ancestor folder updates
      ref.listen(nodeUpdateTriggerProvider, (_, event) {
        debugPrint("received trigger event");
        if (event != null &&
            _isAncestor(ref.read(fileTreeProvider).nodeMap[event.id]!)) {
          debugPrint(
            "ancestor updated (changes in parent/parents position changes)",
          );
          _calculateInheritance();
          _resolveAuth();
          _mergeVariables();
        }
      });
      // only handles immediate parent position changes
      ref.listen(
        fileTreeProvider.select((tree) => tree.nodeMap[id]!.parentId),
        (old, newId) {
          if (old != newId) {
            debugPrint("active request parent changed");
            load(node);
          }
        },
      );
    }
    load(node);
    return ResolveConfig.empty(node);
  }

  bool _isAncestor(Node ancestor) {
    Node? ptr = getParent(getNode);
    while (ptr != null) {
      if (ptr.id == ancestor.id) {
        return true;
      }
      ptr = getParent(ptr);
    }
    return false;
  }

  void load(Node node) async {
    debugPrint("is hydrated: ${node.config.isDetailLoaded}");
    if (!node.config.isDetailLoaded) {
      await hydrateNode(node);
      //notify
      debugPrint("hydrated node: ${node.name}");
      state = state.copyWith(node: node);
    }

    await hydrateAncestors();

    _calculateInheritance();

    _resolveAuth();

    if (node is RequestNode) {
      _mergeVariables();
      await loadHistory();
    }
  }

  Future<void> hydrateNode(Node node) async {
    if (node.config.isDetailLoaded) return;
    final details = await _repo.getNodeDetails(node.id);
    if (details.isNotEmpty) {
      node.hydrate(details);
    }
  }

  FolderNode? getParent(Node node) {
    return ref.read(fileTreeProvider).nodeMap[node.parentId] as FolderNode?;
  }

  Future<void> hydrateAncestors() async {
    Node? ptr = getParent(getNode);
    while (ptr != null) {
      if (!ptr.config.isDetailLoaded) {
        await hydrateNode(ptr);
      }
      ptr = getParent(ptr);
    }
  }

  void _calculateInheritance() {
    List<KeyValueItem> inheritedHeaders = [];
    var ptr = getParent(getNode);
    while (ptr != null) {
      final headers = ptr.config.headers;
      inheritedHeaders.insertAll(0, headers.where((h) => h.isEnabled));
      ptr = getParent(ptr);
    }
    state = state.copyWith(inheritedHeaders: inheritedHeaders);
  }

  void _resolveAuth() {
    final currentAuth = getNode.config.auth;

    // Case 1: Explicit Auth
    if (currentAuth.type != AuthType.inherit) {
      state = state.copyWith(
        effectiveAuth: currentAuth,
        effectiveAuthSource: getNode,
      );
      return;
    }

    // Case 2: Walk the chain
    Node? ptr = getParent(state.node);
    while (ptr != null) {
      final pAuth = ptr.config.auth;

      if (pAuth.type == AuthType.noAuth) {
        state = state.copyWith(
          effectiveAuth: const AuthData(type: AuthType.noAuth),
          effectiveAuthSource: null,
        );
        return;
      }

      if (pAuth.type != AuthType.inherit) {
        state = state.copyWith(effectiveAuth: pAuth, effectiveAuthSource: ptr);
        return;
      }
      ptr = getParent(ptr);
    }

    // Case 3: Root reached
    state = state.copyWith(
      effectiveAuth: const AuthData(type: AuthType.noAuth),
      effectiveAuthSource: null,
    );
  }

  void _mergeVariables() {
    Map<String, VariableValue> allVars = {};

    // Collect the chain from top parent to the current node
    List<FolderNode> chain = [];
    var ptr = getParent(getNode);
    while (ptr != null) {
      chain.insert(0, ptr); // insert at start to reverse order
      ptr = getParent(ptr);
    }

    // Merge variables: top parent first, child later
    for (var node in chain) {
      for (var v in node.config.variables) {
        if (v.isEnabled) {
          // later keys override earlier ones
          allVars[v.key] = VariableValue(node.id, v.value);
        }
      }
    }
    debugPrint("Merged variables: $allVars");
    state = state.copyWith(allVariables: allVars);
  }

  Future<void> loadHistory() async {
    final history = await _repo.getHistory(getNode.id);
    state = state.copyWith(history: history);
  }

  /// Updates
  void updateName(String name) {
    updateNode(getNode.copyWith(name: name));
  }

  void updateMethod(String method) {
    updateNode((getNode as RequestNode).copyWith(method: method));
  }

  void updateUrl(String url) {
    updateNode((getNode as RequestNode).copyWith(url: url));
  }

  void updateDescription(String description) {
    // state = state.copyWith(node: state.node..config.description = description);
    updateNode(
      getNode.copyWith(
        config: getNode.config.copyWith(description: description),
      ),
    );
  }

  void updateHeaders(List<KeyValueItem> headers) {
    updateNode(
      getNode.copyWith(config: getNode.config.copyWith(headers: headers)),
    );
  }

  void updateQueryParameters(List<KeyValueItem> queryParameters) {
    updateNode(
      getNode.copyWith(
        config: (getNode as RequestNode).config.copyWith(
          queryParameters: queryParameters,
        ),
      ),
    );
  }

  void updateAuth(AuthData auth) {
    // state = state.copyWith(node: state.node..config.auth = auth);
    updateNode(getNode.copyWith(config: getNode.config.copyWith(auth: auth)));
  }

  void updateVariables(List<KeyValueItem> variables) {
    // state = state.copyWith(
    //   node: (state.node as FolderNode)..config.variables = variables,
    // );
    updateNode(
      getNode.copyWith(
        config: (getNode.config as FolderNodeConfig).copyWith(
          variables: variables,
        ),
      ),
    );
  }

  void addHistoryEntry(RawHttpResponse entry, {int limit = 10}) {
    final currentHistory = state.history ?? [];
    final updatedHistory = [entry, ...currentHistory];
    if (updatedHistory.length > limit) {
      updatedHistory.removeRange(limit, updatedHistory.length);
    }
    state = state.copyWith(history: updatedHistory);

    // update node last status code
    updateNode(
      (getNode as RequestNode).copyWith(lastStatusCode: entry.statusCode),
    );
    _repo.addHistoryEntry(entry);
  }

  void updateNode(Node node) {
    // notify
    ref.read(fileTreeProvider.notifier).updateNode(node);
    state = state.copyWith(node: node);
  }
}

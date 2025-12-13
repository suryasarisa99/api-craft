import 'package:api_craft/repository/storage_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'repository_provider.dart';

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

  Node get node => state.node;
  late final StorageRepository _repo = ref.read(repositoryProvider);

  @override
  build() {
    final node = ref.read(
      fileTreeProvider.select((treeData) => treeData.nodeMap[id]!),
    );
    debugPrint(
      "Building ResolveConfigNotifier for node ${node.name},: ${node.config.isDetailLoaded}",
    );
    if (node is RequestNode) {
      ref.listen(nodeUpdateTriggerProvider, (_, event) {
        debugPrint("triggered node update for ${node.name}");
        if (event != null &&
            _isAncestor(ref.read(fileTreeProvider).nodeMap[event.id]!)) {
          _calculateInheritance();
          _resolveAuth();
        }
      });
    }
    load();
    return ResolveConfig.empty(node);
  }

  bool _isAncestor(Node ancestor) {
    Node? ptr = getParent(node);
    while (ptr != null) {
      if (ptr.id == ancestor.id) {
        return true;
      }
      ptr = getParent(ptr);
    }
    return false;
  }

  void load() async {
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
    Node? ptr = getParent(node);
    while (ptr != null) {
      if (!ptr.config.isDetailLoaded) {
        await hydrateNode(ptr);
      }
      ptr = getParent(ptr);
    }
  }

  void _calculateInheritance() {
    List<KeyValueItem> inheritedHeaders = [];
    Node? ptr = getParent(node);
    while (ptr != null) {
      final headers = ptr.config.headers;
      inheritedHeaders.insertAll(0, headers.where((h) => h.isEnabled));
      ptr = getParent(ptr);
    }
    // stop notifying here,because it is synchronous calculation,next notify will be in resolve auth
    state = state.copyWith(inheritedHeaders: inheritedHeaders);
    // state.inheritedHeaders?.addAll(inheritedHeaders);
    debugPrint(
      "Inherited Headers for node ${node.name}: ${inheritedHeaders.length}",
    );
  }

  void _resolveAuth() {
    final currentAuth = node.config.auth;

    // Case 1: Explicit Auth
    if (currentAuth.type != AuthType.inherit) {
      state = state.copyWith(
        effectiveAuth: currentAuth,
        effectiveAuthSource: node,
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

  /// Updates
  void updateName(String name) {
    updateNode(node.copyWith(name: name));
  }

  void updateMethod(String method) {
    updateNode((node as RequestNode).copyWith(method: method));
  }

  void updateUrl(String url) {
    updateNode((node as RequestNode).copyWith(url: url));
  }

  void updateDescription(String description) {
    // state = state.copyWith(node: state.node..config.description = description);
    updateNode(
      node.copyWith(config: node.config.copyWith(description: description)),
    );
  }

  void updateHeaders(List<KeyValueItem> headers) {
    updateNode(node.copyWith(config: node.config.copyWith(headers: headers)));
    debugPrint("headers len: ${state.node.config.headers.length}");
  }

  void updateQueryParameters(List<KeyValueItem> queryParameters) {
    updateNode(
      node.copyWith(
        config: (node as RequestNode).config.copyWith(
          queryParameters: queryParameters,
        ),
      ),
    );
  }

  void updateAuth(AuthData auth) {
    // state = state.copyWith(node: state.node..config.auth = auth);
    updateNode(node.copyWith(config: node.config.copyWith(auth: auth)));
  }

  void updateVariables(List<KeyValueItem> variables) {
    // state = state.copyWith(
    //   node: (state.node as FolderNode)..config.variables = variables,
    // );
    updateNode(
      node.copyWith(
        config: (node.config as FolderNodeConfig).copyWith(
          variables: variables,
        ),
      ),
    );
  }

  void updateNode(Node node) {
    // notify
    ref.read(fileTreeProvider.notifier).updateNode(node);
    state = state.copyWith(node: node);
    debugPrint("updated node: $node");
    // reLinkToParent(node);
  }

  /// parent children has node references, so copywith breaks that link
  /// so we need to re-link the updated node to its parent
  // void reLinkToParent(Node node) {
  //   final FolderNode? parent = node.parent as FolderNode?;
  //   if (parent == null) return;
  //   final index = parent.children.indexWhere((n) => n.id == node.id);
  //   if (index != -1) {
  //     parent.children[index] = node;
  //   }
  // }
}

// class ResolverConfigInitializer {
//   final Node node;
//   void Function(Node) onUpdate;
//   ResolverConfigInitializer(this.node, this.onUpdate);

//   // overide equality, if two resolveConfigInitializer with same node id are treated as equal.
//   // so helpful in riverpod family argument based caching.
//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;
//     return other is ResolverConfigInitializer && other.node.id == node.id;
//   }

//   @override
//   int get hashCode => node.id.hashCode;
// }

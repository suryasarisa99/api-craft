import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';

final reqComposeProvider = NotifierProvider.autoDispose
    .family<ReqComposeNotifier, UiRequestContext, String>(
      ReqComposeNotifier.new,
    );

class ReqComposeNotifier extends Notifier<UiRequestContext> {
  final String id;
  ReqComposeNotifier(this.id);

  Node get getNode =>
      ref.read(fileTreeProvider.select((treeData) => treeData.nodeMap[id]!));

  late final StorageRepository _repo = ref.read(repositoryProvider);

  final bodyDebouncer = Debouncer(Duration(milliseconds: 500));

  @override
  build() {
    final treeState = ref.read(fileTreeProvider);
    // if (treeState.isLoading) {
    //   return null;
    // }
    final node = treeState.nodeMap[id]!;
    if (node is RequestNode) {
      ref.listen(environmentProvider.select((s) => s.selectedEnvironment), (
        old,
        newEnv,
      ) {
        if (old != newEnv) {
          debugPrint("environment changed");
          _load();
        }
      });
      ref.listen(nodeUpdateTriggerProvider, (_, event) {
        debugPrint("received trigger event");
        if (event != null &&
            _isAncestor(ref.read(fileTreeProvider).nodeMap[event.id]!)) {
          debugPrint(
            "ancestor updated (changes in parent/parents position changes)",
          );
          _load();
        }
      });
      // only handles immediate parent position changes
      ref.listen(
        fileTreeProvider.select((tree) => tree.nodeMap[id]?.parentId),
        (old, newId) {
          if (old != newId) {
            debugPrint("active request parent changed");
            _load();
          }
        },
      );
    }
    _load();
    return UiRequestContext.empty(node);
  }

  Future<void> _load() async {
    final resolver = RequestResolver(ref);
    final ctx = await resolver.resolveForUi(id);
    state = ctx.copyWith(isLoading: false);

    if (ctx.node is RequestNode) {
      final history = await ref
          .read(repositoryProvider)
          .getHistory(ctx.node.id);
      state = state.copyWith(history: history);
    }
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

  FolderNode? getParent(Node node) {
    return ref.read(fileTreeProvider).nodeMap[node.parentId] as FolderNode?;
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
        config: (getNode.config as RequestNodeConfig).copyWith(
          queryParameters: queryParameters,
        ),
      ),
    );
  }

  void updateScripts(String scripts) {
    updateNode(
      (getNode as RequestNode).copyWith(
        config: (getNode.config as RequestNodeConfig).copyWith(
          scripts: scripts,
        ),
      ),
    );
    _repo.updateScripts(id, scripts);
  }

  void updateBody(String body) {
    debugPrint("update body");
    state = state.copyWith(body: body);
    bodyDebouncer.run(() => _repo.updateRequestBody(id, body));
  }

  void updateBodyType(String? type) {
    var node = getNode as RequestNode;
    var headers = List<KeyValueItem>.from(node.config.headers);

    // Remove existing Content-Type
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
    updateNode((getNode as RequestNode).copyWith(statusCode: entry.statusCode));
    _repo.addHistoryEntry(entry);
  }

  void updateNode(Node node) {
    // notify
    ref.read(fileTreeProvider.notifier).updateNode(node);
    state = state.copyWith(node: node);
  }
}

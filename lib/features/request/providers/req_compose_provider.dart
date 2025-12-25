import 'package:api_craft/features/request/providers/request_details_provider.dart';
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

  @override
  UiRequestContext build() {
    // 1. Watch Node
    final node = ref.watch(
      fileTreeProvider.select((treeData) => treeData.nodeMap[id]!),
    );

    // 2. Watch Details (Body,History & Inheritance Details)
    final detailsState = ref.watch(requestDetailsProvider(id));

    return UiRequestContext(
      node: node,
      body: detailsState.body,
      inheritedHeaders: detailsState.inherit.headers,
      effectiveAuth: detailsState.inherit.auth,
      authSource: detailsState.inherit.authSource,
      allVariables: detailsState.inherit.variables,
      isLoading: detailsState.isLoading,
      history: detailsState.history,
      isSending: stateOrNull?.isSending ?? false,
      sendStartTime: stateOrNull?.sendStartTime,
      sendError: stateOrNull?.sendError,
    );
  }
  // --- ACTIONS (Delegate to appropriate provider) ---

  FileTreeNotifier get _treeNotifier => ref.read(fileTreeProvider.notifier);
  RequestDetailsNotifier get _detailsNotifier =>
      ref.read(requestDetailsProvider(id).notifier);

  void updateName(String name) {
    _treeNotifier.updateNodeName(id, name);
  }

  void updateMethod(String method) {
    _treeNotifier.updateRequestMethod(id, method);
  }

  void updateUrl(String url) {
    _treeNotifier.updateRequestUrl(id, url);
  }

  void updateDescription(String description) {
    _treeNotifier.updateNodeDescription(id, description);
  }

  void updateHeaders(List<KeyValueItem> headers) {
    _treeNotifier.updateNodeHeaders(id, headers);
  }

  void updateQueryParameters(List<KeyValueItem> queryParameters) {
    _treeNotifier.updateRequestQueryParameters(id, queryParameters);
  }

  void updateScripts(String scripts) {
    _treeNotifier.updateRequestScripts(id, scripts);
  }

  void updateBody(String body) {
    _detailsNotifier.updateBody(body);
  }

  void updateBodyType(String? type) {
    _treeNotifier.updateRequestBodyType(id, type);
  }

  void updateAuth(AuthData auth) {
    _treeNotifier.updateNodeAuth(id, auth);
  }

  void updateVariables(List<KeyValueItem> variables) {
    _treeNotifier.updateFolderVariables(id, variables);
  }

  void addHistoryEntry(RawHttpResponse entry, {int limit = 10}) {
    // History State is managed by RequestDetailsProvider
    _detailsNotifier.addHistoryEntry(entry, limit: limit);
    // Ephemeral state for compose provider if any?
    // UiRequestContext has history field, it will update when detailsState updates.
  }

  void startSending() {
    state = state.copyWith(
      isSending: true,
      sendStartTime: DateTime.now(),
      sendError: null,
    );
  }

  void finishSending() {
    state = state.copyWith(isSending: false);
  }

  void setSendError(String error) {
    state = state.copyWith(isSending: false, sendError: error);
  }
}

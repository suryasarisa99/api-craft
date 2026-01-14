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
    var node = ref.watch(
      fileTreeProvider.select((treeData) => treeData.nodeMap[id]),
    );

    // 2. Safety Fallback
    node ??= FolderNode(
      id: id,
      parentId: null,
      name: 'Error: Not Found',
      sortOrder: 0,
      config: FolderNodeConfig(),
    );

    // 3. Watch Details (Body,History & Inheritance Details)
    final detailsState = ref.watch(requestDetailsProvider(id));

    return UiRequestContext(
      node: node,
      body: detailsState.body,
      bodyData: detailsState.bodyData,
      inheritedHeaders: detailsState.inherit.headers,
      effectiveAuth: detailsState.inherit.auth,
      authSource: detailsState.inherit.authSource,
      inheritVariables: detailsState.inherit.variables,
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

  // Removed _colNotifier as updates are now handled via Node updates (FileTreeNotifier)

  void updateName(String name) {
    _treeNotifier.updateNodeName(id, name);
  }

  void updateMethod(String method) {
    _treeNotifier.updateRequestMethod(id, method);
  }

  void updateUrl(String url) {
    _treeNotifier.updateUrl(id, url);
  }

  void updateDescription(String description) {
    // Root Node (Collection) updates are handled same as FolderNode updates
    _treeNotifier.updateDescription(id, description);
  }

  void updateHeaders(List<KeyValueItem> headers) {
    _treeNotifier.updateHeaders(id, headers);
  }

  void updateQueryParameters(List<KeyValueItem> queryParameters) {
    _treeNotifier.updateQueryParameters(id, queryParameters);
  }

  void updateTestScript(String script) {
    _treeNotifier.updateTestScript(id, script);
  }

  void updatePreRequestScript(String script) {
    _treeNotifier.updatePreRequestScript(id, script);
  }

  void updatePostRequestScript(String script) {
    _treeNotifier.updatePostRequestScript(id, script);
  }

  void updateBodyText(String text) {
    _detailsNotifier.updateBodyText(text);
  }

  void updateBodyMap(Map<String, dynamic> map) {
    _detailsNotifier.updateBodyMap(map);
  }

  void updateBodyFile(String path) {
    _detailsNotifier.updateBodyFile(path);
  }

  void updateBodyForm(List<FormDataItem> items) {
    _detailsNotifier.updateBodyForm(items);
  }

  void updateBodyType(String? type) {
    _treeNotifier.updateRequestBodyType(id, type);
  }

  // void updateAuth(AuthData auth) {
  //   _treeNotifier.updateAuth(id, auth);
  // }

  void updateVariables(List<KeyValueItem> variables) {
    _treeNotifier.updateFolderVariables(id, variables);
  }

  void updateAssertions(List<AssertionDefinition> assertions) {
    _treeNotifier.updateAssertions(id, assertions, persist: true);
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

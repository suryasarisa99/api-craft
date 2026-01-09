import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/features/request/models/inherited_request_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../../core/repository/storage_repository.dart';
import '../../../core/repository/data_repository.dart';

final requestDetailsProvider = NotifierProvider.autoDispose
    .family<RequestDetailsNotifier, RequestDetailsState, String>(
      RequestDetailsNotifier.new,
    );

class RequestDetailsState {
  final String? body;
  final InheritedRequest inherit;
  final List<RawHttpResponse>? history;
  final bool isLoading;
  final Map<String, dynamic> bodyData;

  RequestDetailsState({
    this.body,
    this.inherit = const InheritedRequest.empty(),
    this.history,
    this.isLoading = true,
    Map<String, dynamic>? bodyDataRef,
  }) : bodyData = bodyDataRef ?? _parseBody(body);

  static Map<String, dynamic> _parseBody(String? body) {
    if (body == null || body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {"text": body};
    } catch (_) {
      return {"text": body};
    }
  }

  RequestDetailsState copyWith({
    String? body,
    InheritedRequest? inherit,
    List<RawHttpResponse>? history,
    bool? isLoading,
  }) {
    // If body changes, re-parse. If not, keep existing bodyData.
    final newBody = body ?? this.body;
    final shouldReparse = body != null && body != this.body;

    return RequestDetailsState(
      body: newBody,
      inherit: inherit ?? this.inherit,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      bodyDataRef: shouldReparse ? null : bodyData,
    );
  }
}

class RequestDetailsNotifier extends Notifier<RequestDetailsState> {
  final String id;
  RequestDetailsNotifier(this.id);

  late final StorageRepository _repo = ref.read(repositoryProvider);
  late final DataRepository _dataRepo = ref.read(dataRepositoryProvider);
  final _bodyDebouncer = Debouncer(Duration(milliseconds: 500));

  @override
  RequestDetailsState build() {
    _setupListeners();
    ref.listen(environmentProvider, (_, _) {
      refreshInheritance();
    });
    ref.listen(selectedCollectionProvider, (_, _) {
      refreshInheritance();
    });

    _load();
    return RequestDetailsState();
  }

  void _setupListeners() {
    final node = ref.read(fileTreeProvider).nodeMap[id];
    if (node is RequestNode) {
      // Ancestor Changed
      ref.listen(nodeUpdateTriggerProvider, (_, event) {
        if (event != null && _isAncestor(event.id)) {
          refreshInheritance();
        }
      }, fireImmediately: false);
      // Direct parent changed
      ref.listen(
        fileTreeProvider.select((tree) => tree.nodeMap[id]?.parentId),
        (_, _) => refreshInheritance(),
        fireImmediately: false,
      );
    }
  }

  Future<void> _load() async {
    await ref.read(fileTreeProvider.notifier).hydrateNode(id);
    final body = await _repo.getBody(id) ?? '';
    final history = await _dataRepo.getHistory(id);

    // final selectedHistoryIndex = history.indexWhere((e) => e.id == historyId);
    state = RequestDetailsState(
      body: body,
      history: history,
      inherit: await _getInheritance(),
      isLoading: false,
    );
  }

  RawHttpResponse? get selectedHistory {
    final node = ref.read(fileTreeProvider).nodeMap[id];
    final historyId = node is RequestNode ? node.config.historyId : null;

    if (state.history?.isEmpty ?? true) return null;
    if (historyId == null) return state.history!.first;
    return state.history?.firstWhere((e) => e.id == historyId);
  }

  bool _isAncestor(String ancestorId) {
    final tree = ref.read(fileTreeProvider);
    final node = tree.nodeMap[id];
    if (node == null) return false;

    var ptr = node.parentId != null ? tree.nodeMap[node.parentId] : null;
    while (ptr != null) {
      if (ptr.id == ancestorId) return true;
      ptr = ptr.parentId != null ? tree.nodeMap[ptr.parentId] : null;
    }
    return false;
  }

  Future<InheritedRequest> _getInheritance() async {
    final resolver = RequestResolver(ref);
    final x = await resolver.resolveInherit(id);
    debugPrint("Inherited request: ${x.headers.length}");
    return x;
  }

  // --- Body Update Methods ---

  void updateBodyText(String text) {
    final currentData = Map<String, dynamic>.from(state.bodyData);
    currentData['text'] = text;
    // Clear conflicting types to ensure single source of truth for execution
    currentData.remove('file');
    currentData.remove('form');
    _updateBodyInternal(jsonEncode(currentData));
  }

  void updateBodyFile(String path) {
    final currentData = Map<String, dynamic>.from(state.bodyData);
    currentData['file'] = path;
    currentData.remove('text');
    currentData.remove('form');
    _updateBodyInternal(jsonEncode(currentData));
  }

  void updateBodyForm(List<FormDataItem> items) {
    final currentData = Map<String, dynamic>.from(state.bodyData);
    currentData['form'] = items.map((e) => e.toMap()).toList();
    currentData.remove('text');
    currentData.remove('file');
    _updateBodyInternal(jsonEncode(currentData));
  }

  void updateBodyMap(Map<String, dynamic> map) {
    // Merges or sets specific keys.
    // For GraphQL, we want 'query' and 'variables' to coexist with other potential future keys,
    // but clear conflicting types if we want to ensure purity?
    // Actually, let's just merge them in.
    final currentData = Map<String, dynamic>.from(state.bodyData);
    currentData.addAll(map);

    // Ensure we are in a consistent state if switching types
    // But BodyType handles the type.
    _updateBodyInternal(jsonEncode(currentData));
  }

  // Kept for backward compatibility or direct setting if needed, but prefer granular updates.
  // Used by debouncer.
  void _updateBodyInternal(String newBody) {
    state = state.copyWith(body: newBody);
    _bodyDebouncer.run(() => _repo.updateRequestBody(id, newBody));
  }

  void refreshInheritance() async {
    state = state.copyWith(inherit: await _getInheritance());
  }

  void addHistoryEntry(RawHttpResponse entry, {int limit = 10}) {
    final currentHistory = state.history ?? [];
    final updatedHistory = [entry, ...currentHistory];
    if (updatedHistory.length > limit) {
      updatedHistory.removeRange(limit, updatedHistory.length);
    }
    state = state.copyWith(history: updatedHistory);

    final fileTree = ref.read(fileTreeProvider);
    final fileTreeNotifier = ref.read(fileTreeProvider.notifier);
    fileTreeNotifier.updateRequestStatusCode(id, entry.statusCode);
    _dataRepo.addHistoryEntry(entry);
    if ((fileTree.nodeMap[id] as RequestNode).config.historyId != null) {
      fileTreeNotifier.updateRequestHistoryId(id, null);
    }
  }

  void deleteHistory() {
    state = state.copyWith(history: []);
    _dataRepo.clearHistory(id);
  }

  void deleteHistoryEntry(String historyId) {
    state = state.copyWith(
      history: state.history?.where((e) => e.id != historyId).toList(),
    );
    _dataRepo.deleteCurrHistory(historyId);
  }
}

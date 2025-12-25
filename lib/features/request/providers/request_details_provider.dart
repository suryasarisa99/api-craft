import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/features/request/models/inherited_request_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repository/storage_repository.dart';

final requestDetailsProvider =
    NotifierProvider.family<
      RequestDetailsNotifier,
      RequestDetailsState,
      String
    >(RequestDetailsNotifier.new);

class RequestDetailsState {
  final String? body;
  final InheritedRequest inherit;
  final List<RawHttpResponse>? history;
  final bool isLoading;

  RequestDetailsState({
    this.body,
    this.inherit = const InheritedRequest.empty(),
    this.history,
    this.isLoading = true,
  });

  RequestDetailsState copyWith({
    String? body,
    InheritedRequest? inherit,
    List<RawHttpResponse>? history,
    bool? isLoading,
  }) {
    return RequestDetailsState(
      body: body ?? this.body,
      inherit: inherit ?? this.inherit,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RequestDetailsNotifier extends Notifier<RequestDetailsState> {
  final String id;
  RequestDetailsNotifier(this.id);

  late final StorageRepository _repo = ref.read(repositoryProvider);
  final _bodyDebouncer = Debouncer(Duration(milliseconds: 500));

  @override
  RequestDetailsState build() {
    _setupListeners();
    ref.watch(environmentProvider);
    _load();
    return stateOrNull ?? RequestDetailsState();
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
    final history = await _repo.getHistory(id);

    state = RequestDetailsState(
      body: body,
      history: history,
      inherit: await _getInheritance(),
      isLoading: false,
    );
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

  void updateBody(String newBody) {
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

    ref
        .read(fileTreeProvider.notifier)
        .updateRequestStatusCode(id, entry.statusCode);
    _repo.addHistoryEntry(entry);
  }
}

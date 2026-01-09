import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeReqIdProvider = NotifierProvider<ActiveReqIdNotifier, String?>(
  ActiveReqIdNotifier.new,
);

final activeReqProvider = Provider<RequestNode?>((ref) {
  final activeReqId = ref.watch(activeReqIdProvider);
  if (activeReqId == null) return null;

  final node = ref.watch(
    fileTreeProvider.select((treeData) => treeData.nodeMap[activeReqId]),
  );

  return node is RequestNode ? node : null;
});

class ActiveReqIdNotifier extends Notifier<String?> {
  String _getPrefKey(String? collectionId) => collectionId == null
      ? 'active_request_id'
      : 'active_request_id_$collectionId';

  @override
  String? build() {
    final collection = ref.watch(selectedCollectionProvider);
    return getFromPrefs(collection?.id);
  }

  void setActiveId(String? nodeId) {
    state = nodeId;
    final collectionId = ref.read(selectedCollectionProvider)?.id;
    final key = _getPrefKey(collectionId);

    if (nodeId != null) {
      prefs.setString(key, nodeId);
    } else {
      prefs.remove(key);
    }
  }

  String? getFromPrefs(String? collectionId) {
    final key = _getPrefKey(collectionId);
    final id = prefs.getString(key);
    if (id == null) return null;
    return id;
  }
}

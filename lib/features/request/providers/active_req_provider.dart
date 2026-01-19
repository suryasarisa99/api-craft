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
  String _getPrefKey(String? workspaceId) => workspaceId == null
      ? 'active_request_id'
      : 'active_request_id_$workspaceId';

  @override
  String? build() {
    final workspace = ref.watch(selectedWorkspaceProvider);
    return getFromPrefs(workspace?.id);
  }

  void setActiveId(String? nodeId) {
    state = nodeId;
    final workspaceId = ref.read(selectedWorkspaceProvider)?.id;
    final key = _getPrefKey(workspaceId);

    if (nodeId != null) {
      prefs.setString(key, nodeId);
    } else {
      prefs.remove(key);
    }
  }

  String? getFromPrefs(String? workspaceId) {
    final key = _getPrefKey(workspaceId);
    final id = prefs.getString(key);
    if (id == null) return null;
    return id;
  }
}

import 'package:api_craft/globals.dart';
import 'package:api_craft/models/node_model.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final activeReqIdProvider = NotifierProvider<ActiveReqIdNotifier, String?>(
  ActiveReqIdNotifier.new,
);

final activeReqProvider = Provider<RequestNode?>((ref) {
  final activeReqId = ref.watch(activeReqIdProvider);
  if (activeReqId == null) return null;
  return ref.watch(
    fileTreeProvider.select(
      (treeData) => treeData.nodeMap[activeReqId] as RequestNode?,
    ),
  );
});

class ActiveReqIdNotifier extends Notifier<String?> {
  static const _prefKey = 'active_request_id';
  @override
  String? build() {
    return getFromPrefs();
  }

  void setActiveNode(String? nodeId) {
    state = nodeId;
    if (nodeId != null) {
      prefs.setString(_prefKey, nodeId);
    } else {
      prefs.remove(_prefKey);
    }
  }

  String? getFromPrefs() {
    final id = prefs.getString(_prefKey);
    if (id == null) return null;
    return id;
  }
}

import 'package:api_craft/api_client/workspace/selected_workspace_provider.dart';
import 'package:api_craft/api_client/request/models/node_model.dart';
import 'package:api_craft/api_client/sidebar/file_tree_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workspaceNodeProvider = Provider<WorkspaceNode?>((ref) {
  final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
  if (selectedWorkspace == null) return null;

  final node = ref.watch(
    fileTreeProvider.select((state) => state.nodeMap[selectedWorkspace.id]),
  );

  if (node is WorkspaceNode) {
    return node;
  }
  return null;
});

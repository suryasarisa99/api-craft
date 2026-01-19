import 'dart:convert';

import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/features/workspace/workspaces_provider.dart';

final selectedWorkspaceProvider =
    NotifierProvider<SelectedWorkspaceNotifier, WorkspaceModel?>(
      SelectedWorkspaceNotifier.new,
    );

class SelectedWorkspaceNotifier extends Notifier<WorkspaceModel?> {
  static const _prefKey = 'selected_workspace';

  @override
  WorkspaceModel? build() {
    ref.listen(workspacesProvider, (previous, next) {
      final list = next.asData?.value;
      if (list != null && state != null) {
        final fresh = list.where((c) => c.id == state!.id).firstOrNull;
        if (fresh != null && fresh != state) {
          state = fresh;
        } else if (fresh == null) {
          // Selected workspace was deleted, switch to default or first available
          final substitute = list.firstWhere(
            (c) => c.id == kDefaultWorkspace.id,
            orElse: () => list.isNotEmpty ? list.first : kDefaultWorkspace,
          );
          select(substitute);
        }
      }
    });

    final workspaceStr = prefs.getString(_prefKey);
    if (workspaceStr == null) return null;

    final workspace = WorkspaceModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(workspaceStr)),
    );
    return workspace;
  }

  Future<void> select(WorkspaceModel workspace) async {
    // Determine the model to save.
    // Index model is fine, as details are loaded via Root Node.
    await prefs.setString(_prefKey, jsonEncode(workspace.toMap()));
    state = workspace;
  }
}

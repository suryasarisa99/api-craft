import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClipboardNotifier extends Notifier<ClipboardState> {
  @override
  ClipboardState build() => const ClipboardState(nodeIds: {});

  void copy(Set<String> ids) {
    // Smart Selection: Filter out children if their parent is also selected.
    final normalized = _normalizeSelection(ids);
    state = ClipboardState(nodeIds: normalized, action: ClipboardAction.copy);
  }

  void cut(Set<String> ids) {
    final normalized = _normalizeSelection(ids);
    state = ClipboardState(nodeIds: normalized, action: ClipboardAction.cut);
  }

  void clear() {
    state = const ClipboardState(nodeIds: {});
  }

  Set<String> _normalizeSelection(Set<String> rawIds) {
    if (rawIds.isEmpty) return {};

    final tree = ref.read(fileTreeProvider);
    final normalized = <String>{};

    for (final id in rawIds) {
      final node = tree.nodeMap[id];
      if (node == null) continue;

      // Check if any ancestor is also in the selection
      bool ancestorSelected = false;
      var parentId = node.parentId;
      while (parentId != null) {
        if (rawIds.contains(parentId)) {
          ancestorSelected = true;
          break;
        }
        parentId = tree.nodeMap[parentId]?.parentId;
      }

      if (!ancestorSelected) {
        normalized.add(id);
      }
    }
    return normalized;
  }
}

final clipboardProvider = NotifierProvider<ClipboardNotifier, ClipboardState>(
  ClipboardNotifier.new,
);

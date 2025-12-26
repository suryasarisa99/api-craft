import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
// import your fileTreeProvider here

import 'package:api_craft/features/sidebar/providers/sidebar_search_provider.dart';

// 1. Optimized Provider for a Single Tile
// Returns null if node doesn't exist OR if it is filtered out (though UI shouldn't request it if parent didn't list it).
final visualNodeProvider = Provider.autoDispose.family<VisualNode?, String>((
  ref,
  nodeId,
) {
  final node = ref.watch(fileTreeProvider.select((s) => s.nodeMap[nodeId]));
  if (node == null) return null;

  // Filter Logic
  final filteredTree = ref.watch(filteredTreeProvider);

  // If Filter is active, we might modify the 'children' list in the VisualNode
  // so the UI only renders visible children.
  List<String> children = node is FolderNode ? node.children : [];

  if (filteredTree != null) {
    if (!filteredTree.visibleNodes.contains(nodeId)) {
      // Ideally shouldn't happen if parent filtering works, but for safety:
      return null;
    }
    // Filter children
    children = children
        .where((id) => filteredTree.visibleNodes.contains(id))
        .toList();
  }

  return VisualNode.fromNode(node, overrideChildren: children);
});

// 2. Optimized Provider for the Root List
final rootIdsProvider = Provider.autoDispose<RootList>((ref) {
  final treeState = ref.watch(fileTreeProvider);
  final filteredTree = ref.watch(filteredTreeProvider);

  var roots = treeState.nodeMap.values
      .where((n) => n.parentId == null)
      .toList();

  if (filteredTree != null) {
    roots = roots
        .where((n) => filteredTree.visibleNodes.contains(n.id))
        .toList();
  }

  // Sort logic (Must match Drag Logic)
  roots.sort((a, b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return RootList(roots.map((n) => n.id).toList());
});

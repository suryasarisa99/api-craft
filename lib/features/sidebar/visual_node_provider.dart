import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
// import your fileTreeProvider here

// 1. Optimized Provider for a Single Tile
// Returns null if node doesn't exist.
final visualNodeProvider = Provider.autoDispose.family<VisualNode?, String>((
  ref,
  nodeId,
) {
  // Select ONLY the specific node from the map.
  // This prevents the provider from running if OTHER nodes change.
  final node = ref.watch(fileTreeProvider.select((s) => s.nodeMap[nodeId]));

  if (node == null) return null;

  // Convert to VisualNode.
  // Riverpod will compare this new VisualNode with the previous one.
  // If only URL changed, VisualNode equality returns TRUE, and UI update is BLOCKED.
  return VisualNode.fromNode(node);
});

// 2. Optimized Provider for the Root List
final rootIdsProvider = Provider.autoDispose<RootList>((ref) {
  // We watch the whole tree state because adding/removing nodes affects roots
  final treeState = ref.watch(fileTreeProvider);

  final roots = treeState.nodeMap.values
      .where((n) => n.parentId == null)
      .toList();

  // Sort logic (Must match Drag Logic)
  roots.sort((a, b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  // Return wrapped list to enforce content equality
  return RootList(roots.map((n) => n.id).toList());
});

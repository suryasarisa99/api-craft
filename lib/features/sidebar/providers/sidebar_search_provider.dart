import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SidebarSearchState {
  final String query;
  final bool searchFolders;

  const SidebarSearchState({this.query = '', this.searchFolders = false});

  SidebarSearchState copyWith({String? query, bool? searchFolders}) {
    return SidebarSearchState(
      query: query ?? this.query,
      searchFolders: searchFolders ?? this.searchFolders,
    );
  }
}

class SidebarSearchNotifier extends Notifier<SidebarSearchState> {
  @override
  SidebarSearchState build() => const SidebarSearchState();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void toggleSearchFolders() {
    state = state.copyWith(searchFolders: !state.searchFolders);
  }
}

final sidebarSearchProvider =
    NotifierProvider<SidebarSearchNotifier, SidebarSearchState>(
      SidebarSearchNotifier.new,
    );

/// Computed Provider that returns the Filtered View of the Tree
/// It returns:
/// - visibleNodes: Set of IDs that should be shown (matches + ancestors)
/// - expandedNodes: Set of IDs that should be expanded (ancestors of matches)
class FilteredTreeData {
  final Set<String> visibleNodes;
  final Set<String> expandedNodes;
  final Map<String, List<String>> filteredChildren;
  // roots are implicitly those in filteredChildren where parent is null/root,
  // OR we can explicit pass roots.
  // Actually standard way is just a set of visible IDs.
  // But VisualNodeProvider needs to know "what are the children of X?".
  // If we just use visibleNodes, we might show a child that IS visible but shouldn't be under X?
  // No, parent-child is fixed. Visibility is all that matters.
  // EXCEPT if we want to "flatten" the tree? No, user said "show folder too". Hierarchy preserved.

  const FilteredTreeData({
    required this.visibleNodes,
    required this.expandedNodes,
    required this.filteredChildren,
  });
}

final filteredTreeProvider = Provider.autoDispose<FilteredTreeData?>((ref) {
  final searchState = ref.watch(sidebarSearchProvider);
  final tree = ref.watch(fileTreeProvider);

  if (searchState.query.isEmpty) {
    return null; // Null means "show everything normally"
  }

  final query = searchState.query.toLowerCase();
  final searchFolders = searchState.searchFolders;

  final visibleNodes = <String>{};
  final expandedNodes = <String>{};

  // To reconstruct hierarchy efficiently
  // We need to find matches, then walk up.

  for (final node in tree.nodeMap.values) {
    bool isMatch = false;

    if (node is FolderNode) {
      if (searchFolders && node.name.toLowerCase().contains(query)) {
        isMatch = true;
      }
    } else {
      // File
      if (node.name.toLowerCase().contains(query)) {
        isMatch = true;
      }
    }

    if (isMatch) {
      visibleNodes.add(node.id);

      // Walk up
      var parentId = node.parentId;
      while (parentId != null) {
        visibleNodes.add(parentId);
        expandedNodes.add(parentId); // Auto-expand ancestors

        final parent = tree.nodeMap[parentId];
        parentId = parent?.parentId;
      }
    }
  }

  return FilteredTreeData(
    visibleNodes: visibleNodes,
    expandedNodes: expandedNodes,
    filteredChildren: {}, // Not strictly needed if we check visibility in tile?
    // Actually, rootIdsProvider needs to know which roots to show.
    // And Tiles need to know which children to show?
    // If Tile iterates ALL children and checks visibility, that works.
  );
});

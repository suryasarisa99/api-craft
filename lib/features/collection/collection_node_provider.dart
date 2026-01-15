import 'package:api_craft/features/collection/selected_collection_provider.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/features/sidebar/file_tree_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final collectionNodeProvider = Provider<CollectionNode?>((ref) {
  final selectedCollection = ref.watch(selectedCollectionProvider);
  if (selectedCollection == null) return null;

  final node = ref.watch(
    fileTreeProvider.select((state) => state.nodeMap[selectedCollection.id]),
  );

  if (node is CollectionNode) {
    return node;
  }
  return null;
});

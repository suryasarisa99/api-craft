import 'dart:convert';

import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/features/collection/collections_provider.dart';

final selectedCollectionProvider =
    NotifierProvider<SelectedCollectionNotifier, CollectionModel?>(
      SelectedCollectionNotifier.new,
    );

class SelectedCollectionNotifier extends Notifier<CollectionModel?> {
  static const _prefKey = 'selected_collection';

  @override
  CollectionModel? build() {
    ref.listen(collectionsProvider, (previous, next) {
      final list = next.asData?.value;
      if (list != null && state != null) {
        final fresh = list.where((c) => c.id == state!.id).firstOrNull;
        if (fresh != null && fresh != state) {
          state = fresh;
        } else if (fresh == null) {
          // Selected collection was deleted, switch to default or first available
          final substitute = list.firstWhere(
            (c) => c.id == kDefaultCollection.id,
            orElse: () => list.isNotEmpty ? list.first : kDefaultCollection,
          );
          select(substitute);
        }
      }
    });

    final collectionStr = prefs.getString(_prefKey);
    if (collectionStr == null) return null;

    final collection = CollectionModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(collectionStr)),
    );
    return collection;
  }

  Future<void> select(CollectionModel collection) async {
    // Determine the model to save.
    // Index model is fine, as details are loaded via Root Node.
    await prefs.setString(_prefKey, jsonEncode(collection.toMap()));
    state = collection;
  }
}

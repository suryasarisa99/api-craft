import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedCollectionProvider =
    AsyncNotifierProvider<SelectedCollectionNotifier, CollectionModel?>(
      SelectedCollectionNotifier.new,
    );

class SelectedCollectionNotifier extends AsyncNotifier<CollectionModel?> {
  static const _prefKey = 'selected_collection_id';

  @override
  Future<CollectionModel?> build() async {
    final collections = await ref.watch(collectionsProvider.future);
    if (collections.isEmpty) return null;

    final savedId = prefs.getString(_prefKey);

    // Try to find the saved ID in the list
    if (savedId != null) {
      try {
        return collections.firstWhere((c) => c.id == savedId);
      } catch (e) {
        // Saved ID not found (maybe deleted), fall through to default
      }
    }

    // Default: Pick the first one
    final first = collections.first;
    await prefs.setString(_prefKey, first.id);
    return first;
  }

  Future<void> select(CollectionModel collection) async {
    await prefs.setString(_prefKey, collection.id);
    state = AsyncData(collection);
  }
}

import 'package:api_craft/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:uuid/uuid.dart';

final collectionsProvider =
    AsyncNotifierProvider<CollectionsNotifier, List<CollectionModel>>(
      CollectionsNotifier.new,
    );

class CollectionsNotifier extends AsyncNotifier<List<CollectionModel>> {
  @override
  Future<List<CollectionModel>> build() async {
    final db = await ref.watch(databaseProvider);

    // Fetch existing
    final maps = await db.query('collections');
    debugPrint('Collections found: ${maps.length}');

    if (maps.isNotEmpty) {
      return maps.map((e) => CollectionModel.fromMap(e)).toList();
    } else {
      // DEFAULT LOGIC: If empty, create default 'api_craft' DB collection
      final defaultCollection = CollectionModel(
        id: 'default_api_craft',
        name: 'API Craft',
        type: CollectionType.database,
      );

      await db.insert('collections', defaultCollection.toMap());
      return [defaultCollection];
    }
  }

  Future<void> createCollection(
    String name, {
    CollectionType type = CollectionType.database,
    String? path,
  }) async {
    final db = await ref.read(databaseProvider);
    final newId = const Uuid().v4();

    final newCollection = CollectionModel(
      id: newId,
      name: name,
      type: type,
      path: path,
    );

    await db.insert('collections', newCollection.toMap());

    // Refresh list
    ref.invalidateSelf();

    // Auto-select the new collection?
    ref.read(selectedCollectionProvider.notifier).select(newCollection);
  }
}

/// use shared preferences to store collections instead of database

// class CollectionsProvider extends Notifier<List<CollectionModel>> {
//   static const _collectionsKey = 'collections';

//   @override
//   List<CollectionModel> build() {
//     final prefs = loadCollections();
//     if (prefs.isEmpty) {
//       return [];
//     }
//     return prefs;
//   }

//   Future<void> addCollection(CollectionModel collection) async {
//     final prefs = await SharedPreferences.getInstance();
//     final collectionsData = prefs.getStringList(_collectionsKey) ?? [];
//     collectionsData.add(jsonEncode(collection.toMap()));
//     await prefs.setStringList(_collectionsKey, collectionsData);
//     state = [...state, collection];
//   }

//   List<CollectionModel> loadCollections() {
//     return prefs.getStringList(_collectionsKey)?.map((data) {
//           final map = jsonDecode(data);
//           return CollectionModel.fromMap(map);
//         }).toList() ??
//         [];
//   }
// }

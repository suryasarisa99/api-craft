import 'package:api_craft/core/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/repository/data_repository.dart';
import 'package:nanoid/nanoid.dart';

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
      // Should have been created by DBHelper init, but if not, return empty or retry
      return [];
    }
  }

  Future<CollectionModel> createCollection(
    String name, {
    CollectionType type = CollectionType.database,
    String? path,
  }) async {
    final db = await ref.read(databaseProvider);
    final newId = nanoid();

    final newCollection = CollectionModel(
      id: newId,
      name: name,
      type: type,
      path: path,
    );

    await db.insert('collections', newCollection.toMap());

    // Create Default Environment & Cookie Jar for this new collection
    // Use a scoped DataRepo for the new collection
    final dataRepo = DataRepository(Future.value(db), newId);

    await dataRepo.createEnvironment(
      Environment(id: nanoid(), collectionId: newId, name: 'Default'),
    );

    await dataRepo.createCookieJar(
      CookieJarModel(id: nanoid(), collectionId: newId, name: 'Default'),
    );

    // Refresh list
    ref.invalidateSelf();

    return newCollection;
  }

  Future<void> deleteCollection(String id) async {
    final db = await ref.read(databaseProvider);
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);

    // Refresh list
    ref.invalidateSelf();

    // If deleted collection was selected, switch to default
    // Handled by SelectedCollectionNotifier listener
  }

  Future<void> updateCollection(CollectionModel collection) async {
    final db = await ref.read(databaseProvider);
    await db.update(
      'collections',
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
    // Update state locally to avoid reload flicker
    state.whenData((list) {
      final index = list.indexWhere((c) => c.id == collection.id);
      if (index != -1) {
        final newList = List<CollectionModel>.from(list);
        newList[index] = collection;
        state = AsyncData(newList);
      }
    });
  }

  void updateDescription(String id, String description) {
    state.whenData((list) {
      final collection = list.firstWhere(
        (c) => c.id == id,
        orElse: () => list.first,
      );
      if (collection.id == id) {
        updateCollection(collection.copyWith(description: description));
      }
    });
  }

  void updateHeaders(String id, List<KeyValueItem> headers) {
    state.whenData((list) {
      final collection = list.firstWhere(
        (c) => c.id == id,
        orElse: () => list.first,
      );
      if (collection.id == id) {
        updateCollection(collection.copyWith(headers: headers));
      }
    });
  }

  void updateAuth(String id, AuthData auth) {
    state.whenData((list) {
      final collection = list.firstWhere(
        (c) => c.id == id,
        orElse: () => list.first,
      );
      if (collection.id == id) {
        updateCollection(collection.copyWith(auth: auth));
      }
    });
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

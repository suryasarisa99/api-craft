import 'package:api_craft/core/database/entities/collection_entity.dart';
import 'package:api_craft/core/database/objectbox.dart';
import 'package:api_craft/objectbox.g.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/repository/data_repository.dart';
import 'package:nanoid/nanoid.dart';
import 'package:api_craft/core/database/database_provider.dart';

final collectionsProvider =
    AsyncNotifierProvider<CollectionsNotifier, List<CollectionModel>>(
      CollectionsNotifier.new,
    );

class CollectionsNotifier extends AsyncNotifier<List<CollectionModel>> {
  Future<Box<CollectionEntity>> get _box async =>
      (await ref.watch(databaseProvider)).store.box<CollectionEntity>();

  @override
  Future<List<CollectionModel>> build() async {
    final box = await _box;

    // Fetch existing
    final entities = box.getAll();
    debugPrint('Collections found: ${entities.length}');

    if (entities.isNotEmpty) {
      return entities.map((e) => e.toModel()).toList();
    } else {
      return [];
    }
  }

  Future<CollectionModel> createCollection(
    String name, {
    CollectionType type = CollectionType.database,
    String? path,
  }) async {
    final obx = await ref.read(databaseProvider);
    final box = obx.store.box<CollectionEntity>();

    final newId = nanoid();

    final newCollection = CollectionModel(
      id: newId,
      name: name,
      type: type,
      path: path,
    );

    box.put(CollectionEntity.fromModel(newCollection));

    // Create Default Environment & Cookie Jar for this new collection
    // Use a scoped DataRepo for the new collection
    final dataRepo = DataRepository(Future.value(obx), newId);

    await dataRepo.createEnvironment(
      Environment(
        id: nanoid(),
        collectionId: newId,
        name: 'Global',
        isGlobal: true,
      ),
    );

    await dataRepo.createCookieJar(
      CookieJarModel(id: nanoid(), collectionId: newId, name: 'Default'),
    );

    // Refresh list
    ref.invalidateSelf();

    return newCollection;
  }

  Future<void> deleteCollection(String id) async {
    final box = await _box;
    final q = box.query(CollectionEntity_.uid.equals(id)).build();
    q.remove();
    q.close();

    // Refresh list
    ref.invalidateSelf();
  }

  Future<void> updateCollection(CollectionModel collection) async {
    final box = await _box;

    // Check internal ID
    final q = box.query(CollectionEntity_.uid.equals(collection.id)).build();
    final existing = q.findFirst();
    q.close();

    if (existing != null) {
      final updated = CollectionEntity.fromModel(collection);
      updated.id = existing.id; // Preserve ID
      box.put(updated);
    }

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

import 'package:api_craft/core/database/entities/collection_entity.dart';
import 'package:api_craft/core/repository/objectbox_storage_repository.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:api_craft/objectbox.g.dart';
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
  Future<Box<CollectionEntity>> get _box async =>
      (await ref.watch(databaseProvider)).store.box<CollectionEntity>();

  @override
  Future<List<CollectionModel>> build() async {
    final box = await _box;

    // Fetch existing (Index only from DB)
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

    // Create Root Node (FolderNode) for this collection
    StorageRepository repo;
    if (type == CollectionType.database) {
      repo = ObjectBoxStorageRepository(Future.value(obx), newId);
    } else {
      repo = FlatFileStorageRepository(rootPath: path!);
    }

    final rootNode = FolderNode(
      id: newId, // Root ID same as Collection ID
      parentId: null,
      name: name,
      config: FolderNodeConfig(isDetailLoaded: true),
      sortOrder: -1,
    );

    await repo.createOne(rootNode);

    // Create Default Environment & Cookie Jar
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
      // 1. Check for Name Change & Sync Root Node
      if (existing.name != collection.name) {
        try {
          // Instantiate scoped repo to update Root Node
          StorageRepository repo;
          if (collection.type == CollectionType.database) {
            final obx = await ref.read(databaseProvider);
            repo = ObjectBoxStorageRepository(Future.value(obx), collection.id);
          } else {
            if (collection.path != null) {
              repo = FlatFileStorageRepository(rootPath: collection.path!);
            } else {
              throw Exception("Filesystem collection missing path");
            }
          }
          await repo.renameItem(collection.id, collection.name);

          // Invalidate Tree if this is the selected collection
          // to reflect the name change immediately in the UI tree
          final selectedId = ref.read(selectedCollectionProvider)?.id;
          if (selectedId == collection.id) {
            ref.invalidate(fileTreeProvider);
          }
        } catch (e) {
          debugPrint("Error syncing collection name to root node: $e");
        }
      }

      // 2. Just update DB Index
      final updated = CollectionEntity.fromModel(collection);
      updated.id = existing.id; // Preserve ID
      box.put(updated);
    }

    // Update state locally
    state.whenData((list) {
      final index = list.indexWhere((c) => c.id == collection.id);
      if (index != -1) {
        final newList = List<CollectionModel>.from(list);
        newList[index] = collection;
        state = AsyncData(newList);
      }
    });
  }
}

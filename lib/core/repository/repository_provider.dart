import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

final repositoryProvider = Provider<StorageRepository>((ref) {
  // 1. Await the Selected Collection (Handles loading state automatically)
  final (collectionId, type) = ref.watch(
    selectedCollectionProvider.select((c) => (c?.id, c?.type)),
  );

  if (collectionId == null) {
    Future.delayed(const Duration(milliseconds: 100), () {
      ref.read(selectedCollectionProvider.notifier).select(kDefaultCollection);
    });
  }

  // 2. Return the correct Repository based on type
  if (collectionId == null || type == CollectionType.database) {
    final db = ref.watch(databaseProvider);
    return DbStorageRepository(db, collectionId!);
  } else {
    // return FolderStorageRepository(rootPath: collection.path!);
    return FolderStorageRepository(rootPath: collectionId);
  }
});

/* Old Way
- collections provider: get collections (async)
- saved collections provider: get saved collection from prefs (async due to depends on collections)
- repository provider: get storage repository (async due to waiting for db connection and depends on selected collection)
*/

/* New Way
- get saved collection from prefs
  - it is empty return null
- check first time app launched
  - if yes, 
    - db automatically creates default collection. and sets as selected by repository provider after a delay
- repository provider does not waits for db connection,just passes future of db to DbStorageRepository
- DbStorageRepository handles loading state internally when db is needed
- so in ui we can directly use repository provider without waiting
*/

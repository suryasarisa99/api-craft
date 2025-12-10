import 'package:api_craft/models/models.dart';
import 'package:api_craft/repository/storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

final repositoryProvider = FutureProvider<StorageRepository>((ref) async {
  // 1. Await the Selected Collection (Handles loading state automatically)
  final collection = await ref.watch(selectedCollectionProvider.future);

  if (collection == null) {
    // This case theoretically shouldn't happen if your notifier ensures a default,
    // but good to handle safely.
    throw Exception("No collection selected");
  }

  // 2. Return the correct Repository based on type
  if (collection.type == CollectionType.database) {
    final db = await ref.watch(databaseProvider.future);
    return DbStorageRepository(db, collection.id);
  } else {
    return FolderStorageRepository(rootPath: collection.path!);
  }
});

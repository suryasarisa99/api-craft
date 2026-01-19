import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'package:api_craft/core/repository/data_repository.dart';
import 'package:api_craft/core/repository/objectbox_storage_repository.dart';

final repositoryProvider = Provider<StorageRepository>((ref) {
  // 1. Await the Selected Workspace (Handles loading state automatically)
  final (workspaceId, type, path) = ref.watch(
    selectedWorkspaceProvider.select((c) => (c?.id, c?.type, c?.path)),
  );

  if (workspaceId == null) {
    Future.delayed(const Duration(milliseconds: 100), () {
      ref.read(selectedWorkspaceProvider.notifier).select(kDefaultWorkspace);
    });
  }

  // 2. Return the correct Repository based on type
  if (workspaceId == null || type == WorkspaceType.database) {
    final obxFuture = ref.watch(databaseProvider);
    return ObjectBoxStorageRepository(obxFuture, workspaceId!);
  } else {
    // Flat File
    return FlatFileStorageRepository(rootPath: path!);
  }
});

final dataRepositoryProvider = Provider<DataRepository>((ref) {
  // Data is ALWAYS local (DB), regardless of workspace type
  final obxFuture = ref.watch(databaseProvider);
  final workspaceId = ref.watch(
    selectedWorkspaceProvider.select((c) => c?.id ?? kDefaultWorkspace.id),
  );
  return DataRepository(obxFuture, workspaceId);
});

/* Old Way
- workspaces provider: get workspaces (async)
- saved workspaces provider: get saved workspace from prefs (async due to depends on workspaces)
- repository provider: get storage repository (async due to waiting for db connection and depends on selected workspace)
*/

/* New Way
- get saved workspace from prefs
  - it is empty return null
- check first time app launched
  - if yes, 
    - db automatically creates default workspace. and sets as selected by repository provider after a delay
- repository provider does not waits for db connection,just passes future of db to DbStorageRepository
- DbStorageRepository handles loading state internally when db is needed
- so in ui we can directly use repository provider without waiting
*/

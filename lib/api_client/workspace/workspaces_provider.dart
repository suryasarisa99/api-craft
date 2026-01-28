import 'package:api_craft/core/database/entities/workspace_entity.dart';
import 'package:api_craft/core/repository/objectbox_storage_repository.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:api_craft/objectbox.g.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/repository/data_repository.dart';
import 'package:nanoid/nanoid.dart';

final workspacesProvider =
    AsyncNotifierProvider<WorkspacesNotifier, List<WorkspaceModel>>(
      WorkspacesNotifier.new,
    );

class WorkspacesNotifier extends AsyncNotifier<List<WorkspaceModel>> {
  Future<Box<WorkspaceEntity>> get _box async =>
      (await ref.watch(databaseProvider)).store.box<WorkspaceEntity>();

  @override
  Future<List<WorkspaceModel>> build() async {
    final box = await _box;

    // Fetch existing (Index only from DB)
    final entities = box.getAll();
    debugPrint('Workspaces found: ${entities.length}');

    if (entities.isNotEmpty) {
      return entities.map((e) => e.toModel()).toList();
    } else {
      return [];
    }
  }

  Future<WorkspaceModel> createWorkspace(
    String name, {
    WorkspaceType type = WorkspaceType.database,
    String? path,
  }) async {
    final obx = await ref.read(databaseProvider);
    final box = obx.store.box<WorkspaceEntity>();

    final newId = nanoid();

    final newWorkspace = WorkspaceModel(
      id: newId,
      name: name,
      type: type,
      path: path,
    );

    box.put(WorkspaceEntity.fromModel(newWorkspace));

    // Create Root Node (FolderNode) for this workspace
    StorageRepository repo;
    if (type == WorkspaceType.database) {
      repo = ObjectBoxStorageRepository(Future.value(obx), newId);
    } else {
      repo = FlatFileStorageRepository(rootPath: path!);
    }

    final rootNode = FolderNode(
      id: newId, // Root ID same as Workspace ID
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
        workspaceId: newId,
        name: 'Global',
        isGlobal: true,
      ),
    );

    await dataRepo.createCookieJar(
      CookieJarModel(id: nanoid(), workspaceId: newId, name: 'Default'),
    );

    // Refresh list
    ref.invalidateSelf();

    return newWorkspace;
  }

  Future<void> deleteWorkspace(String id) async {
    final box = await _box;
    final q = box.query(WorkspaceEntity_.uid.equals(id)).build();
    q.remove();
    q.close();

    // Refresh list
    ref.invalidateSelf();
  }

  Future<void> updateWorkspace(WorkspaceModel workspace) async {
    final box = await _box;

    // Check internal ID
    final q = box.query(WorkspaceEntity_.uid.equals(workspace.id)).build();
    final existing = q.findFirst();
    q.close();

    if (existing != null) {
      // 1. Check for Name Change & Sync Root Node
      if (existing.name != workspace.name) {
        try {
          // Instantiate scoped repo to update Root Node
          StorageRepository repo;
          if (workspace.type == WorkspaceType.database) {
            final obx = await ref.read(databaseProvider);
            repo = ObjectBoxStorageRepository(Future.value(obx), workspace.id);
          } else {
            if (workspace.path != null) {
              repo = FlatFileStorageRepository(rootPath: workspace.path!);
            } else {
              throw Exception("Filesystem workspace missing path");
            }
          }
          await repo.renameItem(workspace.id, workspace.name);

          // Invalidate Tree if this is the selected workspace
          // to reflect the name change immediately in the UI tree
          final selectedId = ref.read(selectedWorkspaceProvider)?.id;
          if (selectedId == workspace.id) {
            // Update the tree node name directly without rebuilding the whole tree
            ref
                .read(fileTreeProvider.notifier)
                .updateNodeName(workspace.id, workspace.name);
          }
        } catch (e) {
          debugPrint("Error syncing workspace name to root node: $e");
        }
      }

      // 2. Just update DB Index
      final updated = WorkspaceEntity.fromModel(workspace);
      updated.id = existing.id; // Preserve ID
      box.put(updated);
    }

    // Update state locally
    state.whenData((list) {
      final index = list.indexWhere((c) => c.id == workspace.id);
      if (index != -1) {
        final newList = List<WorkspaceModel>.from(list);
        newList[index] = workspace;
        state = AsyncData(newList);
      }
    });
  }
}

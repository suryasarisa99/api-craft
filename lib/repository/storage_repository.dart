import 'package:api_craft/models/models.dart';

export 'folder_storage_repository.dart';
export 'db_storage_repository.dart';

abstract class StorageRepository {
  /// Loads children for a given parent (or root if parentId is empty/null)
  Future<List<FileNode>> getContents(String? parentId);

  /// Creates a new item. Returns the new ID.
  Future<String> createItem({
    required String? parentId,
    required String name,
    required NodeType type,
  });

  /// Deletes an item (and its children).
  Future<void> deleteItem(String id);

  /// Renames an item.
  /// Returns the NEW ID if the ID changed (FileSystem), or null/same ID if it didn't (Database).
  Future<String?> renameItem(String id, String newName);

  /// Moves an item to a new parent.
  /// Returns the NEW ID if the ID changed.
  Future<String?> moveItem(String id, String? newParentId);

  /// Updates the sort order of children within a parent.
  Future<void> saveSortOrder(String? parentId, List<String> orderedIds);

  /// Duplicates an item.
  Future<void> duplicateItem(String id);
}

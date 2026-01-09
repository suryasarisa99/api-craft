import 'package:api_craft/core/models/models.dart';

export 'flat_file_storage_repository.dart';

abstract class StorageRepository {
  /// Loads children for a given parent (or root if parentId is empty/null)
  Future<List<Node>> getNodes();
  Future<Map<String, dynamic>> getNodeDetails(String id);
  Future<String?> getBody(String id);

  /// Creates a new item. Returns the new ID.
  Future<String> createItem({
    required String? parentId,
    required String name,
    required NodeType type,
    String? requestType,
    String? method,
  });

  /// Deletes list of items (not their children).
  Future<void> deleteItems(List<String> ids);

  /// Renames an item.
  /// Returns the NEW ID if the ID changed (FileSystem), or null/same ID if it didn't (Database).
  Future<String?> renameItem(String id, String newName);

  /// Moves an item to a new parent.
  /// Returns the NEW ID if the ID changed.
  Future<String?> moveItem(String id, String? newParentId);

  /// Updates the sort order of children within a parent.
  Future<void> saveSortOrder(String? parentId, List<String> orderedIds);

  Future<void> createOne(Node node);
  Future<void> createMany(List<Node> nodes);

  // --- Collections ---
  // Managed by DataRepository explicitly now? Or leave updateCollectionSelection here?
  // User said "keep only requests/folders and environement detail methods".
  // Collection Selection is technically config, but private config in DB.
  // It was moved to DataRepository.

  /// Reads the configuration columns (headers, auth, vars, desc) for a node
  // Future<NodeConfig> getNodeConfig(String id);

  /// Updates only the configuration columns for a node
  // Future<void> saveNodeConfig(String id, NodeConfig config);

  Future<void> updateNode(Node node);
  Future<void> updateRequestBody(String id, String body);
  Future<void> updateScripts(String id, String scripts);

  Future<void> setHistoryIndex(String requestId, String? historyId);

  // --- Environments ---
  Future<List<Environment>> getEnvironments(String collectionId);
  Future<void> createEnvironment(Environment env);
  Future<void> updateEnvironment(Environment env);
  Future<void> deleteEnvironment(String id);
}

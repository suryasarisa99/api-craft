import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';

import 'package:api_craft/features/request/models/websocket_session.dart';

export 'folder_storage_repository.dart';
export 'db_storage_repository.dart';

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

  /// Deletes an item (and its children).
  Future<void> deleteItem(String id);
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

  /// Reads the configuration columns (headers, auth, vars, desc) for a node
  // Future<NodeConfig> getNodeConfig(String id);

  /// Updates only the configuration columns for a node
  // Future<void> saveNodeConfig(String id, NodeConfig config);

  Future<void> updateNode(Node node);
  Future<void> updateRequestBody(String id, String body);
  Future<void> updateScripts(String id, String scripts);

  ///
  Future<void> addHistoryEntry(RawHttpResponse entry, {int limit = 10});
  Future<List<RawHttpResponse>> getHistory(String requestId, {int limit = 10});
  Future<void> clearHistory(String requestId);
  Future<void> clearHistoryForCollection();

  // --- Environments ---
  Future<List<Environment>> getEnvironments(String collectionId);
  Future<void> createEnvironment(Environment env);
  Future<void> updateEnvironment(Environment env);
  Future<void> deleteEnvironment(String id);

  // --- Cookie Jars ---
  Future<List<CookieJarModel>> getCookieJars(String collectionId);
  Future<void> createCookieJar(CookieJarModel jar);
  Future<void> updateCookieJar(CookieJarModel jar);
  Future<void> deleteCookieJar(String id);

  // --- WebSocket ---
  Future<void> createWebSocketSession(WebSocketSession session);
  Future<void> updateWebSocketSession(WebSocketSession session);
  Future<List<WebSocketSession>> getWebSocketSessions(String requestId);
  Future<void> deleteWebSocketSession(String sessionId);

  Future<void> addWebSocketMessage(WebSocketMessage msg);
  Future<List<WebSocketMessage>> getWebSocketMessages(
    String sessionId, {
    int limit = 100,
  });
  Future<void> clearWebSocketSessionMessages(String sessionId);
}

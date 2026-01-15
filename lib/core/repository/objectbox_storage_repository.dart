import 'package:api_craft/core/database/entities/node_entity.dart';
import 'package:api_craft/core/database/objectbox.dart';
import 'package:api_craft/objectbox.g.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:api_craft/core/constants/globals.dart'; // Added import
import 'package:flutter/cupertino.dart';
import 'package:nanoid/nanoid.dart';
import 'package:api_craft/core/database/entities/environment_entity.dart';
import 'package:api_craft/core/database/entities/collection_entity.dart';

class ObjectBoxStorageRepository implements StorageRepository {
  final Future<ObjectBox> _obxFuture;
  final String collectionId;

  ObjectBoxStorageRepository(this._obxFuture, String? _collectionId)
    : collectionId = _collectionId ?? kDefaultCollection.id;

  // Async getters for boxes
  Future<Box<NodeEntity>> get _nodeBox async =>
      (await _obxFuture).store.box<NodeEntity>();
  Future<Box<EnvironmentEntity>> get _envBox async =>
      (await _obxFuture).store.box<EnvironmentEntity>();

  @override
  Future<String> createItem({
    required String? parentId,
    required String name,
    required NodeType type,
    String? requestType,
    String? method,
  }) async {
    final box = await _nodeBox;
    // Determine sort_order
    final q = box
        .query(
          NodeEntity_.collectionId.equals(collectionId) &
              (parentId == null
                  ? NodeEntity_.parentId.isNull()
                  : NodeEntity_.parentId.equals(parentId)),
        )
        .order(NodeEntity_.sortOrder, flags: Order.descending)
        .build();

    final lastNode = q.findFirst();
    q.close();

    final int nextOrder = (lastNode?.sortOrder ?? -1) + 1;
    final newId = nanoid();

    final entity = NodeEntity(
      uid: newId,
      collectionId: collectionId,
      parentId: parentId,
      name: name,
      type: type.name, // Enum Name
      requestType: requestType,
      method: method,
      sortOrder: nextOrder,
      headers: <Map<String, dynamic>>[],
      auth: const AuthData().toMap(), // Flex
      variables: <Map<String, dynamic>>[],
      queryParameters: <Map<String, dynamic>>[],
    );

    box.put(entity);
    return newId;
  }

  @override
  Future<void> createMany(List<Node> nodes) async {
    final box = await _nodeBox;
    final entities = nodes
        .map((n) => NodeEntity.fromModel(n, collectionId))
        .toList();
    box.putMany(entities);
  }

  @override
  Future<void> createOne(Node node) async {
    final box = await _nodeBox;
    box.put(NodeEntity.fromModel(node, collectionId));
  }

  @override
  Future<String?> getBody(String id) async {
    final box = await _nodeBox;
    final q = box.query(NodeEntity_.uid.equals(id)).build();
    final node = q.findFirst();
    q.close();
    return node?.body;
  }

  @override
  Future<Map<String, dynamic>> getNodeDetails(String id) async {
    final box = await _nodeBox;
    final q = box.query(NodeEntity_.uid.equals(id)).build();
    final node = q.findFirst();
    q.close();

    if (node == null) return {};

    return {
      'description': node.description,
      'headers': node.headers,
      'auth': node.auth,
      'variables': node.variables,
      'query_parameters': node.queryParameters,
      'body_type': node.bodyType,
      'scripts': node.scripts,
      'history_id': node.historyId,
    };
  }

  @override
  Future<List<Node>> getNodes() async {
    final box = await _nodeBox;
    final q = box
        .query(NodeEntity_.collectionId.equals(collectionId))
        .order(NodeEntity_.sortOrder)
        .build();
    final entities = q.find();
    q.close();

    return entities.map((e) => e.toModel()).toList();
  }

  @override
  Future<String?> moveItem(String id, String? newParentId) async {
    final box = await _nodeBox;
    final node = await _findNode(id);
    if (node != null) {
      node.parentId = newParentId;
      box.put(node);
      return id;
    }
    return null;
  }

  @override
  Future<String?> renameItem(String id, String newName) async {
    final box = await _nodeBox;
    final node = await _findNode(id);
    if (node != null) {
      node.name = newName;
      box.put(node);
      return id;
    }
    return null;
  }

  @override
  Future<void> saveSortOrder(String? parentId, List<String> orderedIds) async {
    final box = await _nodeBox;
    final q = box.query(NodeEntity_.uid.oneOf(orderedIds)).build();
    final nodes = q.find();
    q.close();

    final map = {for (var n in nodes) n.uid: n};

    for (int i = 0; i < orderedIds.length; i++) {
      final node = map[orderedIds[i]];
      if (node != null) {
        node.sortOrder = i;
      }
    }
    box.putMany(nodes);
  }

  @override
  Future<void> setHistoryIndex(String requestId, String? historyId) async {
    final box = await _nodeBox;
    final node = await _findNode(requestId);
    if (node != null) {
      node.historyId = historyId;
      box.put(node);
    }
  }

  Future<void> deleteItem(String id) async {
    final box = await _nodeBox;
    final node = await _findNode(id);
    if (node != null) {
      box.remove(node.id);
    }
  }

  @override
  Future<void> deleteItems(List<String> ids) async {
    for (var id in ids) {
      await deleteItem(id);
    }
  }

  @override
  Future<void> updateNode(Node node) async {
    final box = await _nodeBox;
    final existing = await _findNode(node.id);
    if (existing != null) {
      final updated = NodeEntity.fromModel(node, collectionId);
      updated.id = existing.id; // Preserve internal ID
      updated.body = existing.body; // Preserve Body content
      box.put(updated);
    }
  }

  @override
  Future<void> updateRequestBody(String id, String body) async {
    final box = await _nodeBox;
    final node = await _findNode(id);
    if (node != null) {
      node.body = body;
      box.put(node);
    }
  }

  @override
  Future<void> updateScripts(String id, String scripts) async {
    final box = await _nodeBox;
    final node = await _findNode(id);
    if (node != null) {
      node.scripts = scripts;
      box.put(node);
    }
  }

  // --- Environment methods ---

  @override
  Future<void> createEnvironment(Environment env) async {
    final box = await _envBox;
    final q = box.query(EnvironmentEntity_.uid.equals(env.id)).build();
    final existing = q.findFirst();
    q.close();

    final entity = EnvironmentEntity.fromModel(env);
    if (existing != null) entity.id = existing.id;
    box.put(entity);
  }

  @override
  Future<void> deleteEnvironment(String id) async {
    final box = await _envBox;
    final q = box.query(EnvironmentEntity_.uid.equals(id)).build();
    q.remove();
    q.close();
  }

  @override
  Future<void> setCollectionEncryption(String id, String encryptedKey) async {
    // Determine the root node UID.
    // In our architecture, the collection ID is often used as the root folder ID,
    // OR there is a node with ID=collectionId.
    // Let's assume the root node has uid == id (collection id).

    final box = await _nodeBox;
    final q = box.query(NodeEntity_.uid.equals(id)).build();
    final node = q.findFirst();
    q.close();

    if (node != null) {
      // Update the node's encryptedKey
      // node is a NodeEntity, so we update the field directly.
      node.encryptedKey = encryptedKey;
      box.put(node);
    } else {
      // If root node doesn't exist (rare for synced collection?), create it?
      // Usually it should exist if `getNodes` fetches it.
      debugPrint("Warning: Root node not found for encryption update: $id");
    }
  }

  @override
  Future<List<Environment>> getEnvironments(String collectionId) async {
    final box = await _envBox;
    final q = box
        .query(EnvironmentEntity_.collectionId.equals(collectionId))
        .build();
    final res = q.find();
    q.close();
    return res.map((e) => e.toModel()).toList();
  }

  @override
  Future<void> updateEnvironment(Environment env) async {
    await createEnvironment(env);
  }

  // --- Helper ---
  Future<NodeEntity?> _findNode(String uid) async {
    final box = await _nodeBox;
    final q = box.query(NodeEntity_.uid.equals(uid)).build();
    final res = q.findFirst();
    q.close();
    return res;
  }
}

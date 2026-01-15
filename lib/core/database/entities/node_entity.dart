import 'package:objectbox/objectbox.dart';
import 'package:api_craft/core/models/models.dart';

@Entity()
class NodeEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  @Index()
  String collectionId;

  @Index()
  String? parentId;

  String name;
  String type; // 'Request' or 'Folder'

  // Specific fields
  String? method;
  String? requestType;
  int sortOrder;

  // Added field
  int? statusCode;

  // Flex Properties: List<Map> instead of Map
  List<Map<String, dynamic>>? headers;
  Map<String, dynamic>? auth;
  String? url;
  List<Map<String, dynamic>>? queryParameters;

  String? body;
  String? bodyType;
  String? preRequestScript;
  String? postRequestScript;
  String? scripts;
  String? historyId;
  String? description;

  // Folder specific - List<Map>
  List<Map<String, dynamic>>? variables;
  List<Map<String, dynamic>>? assertions; // New field for assertions
  String? encryptedKey; // Added field for collection security

  NodeEntity({
    this.id = 0,
    required this.uid,
    required this.collectionId,
    this.parentId,
    required this.name,
    required this.type,
    this.method,
    this.requestType,
    this.sortOrder = 0,
    this.headers,
    this.auth,
    this.url,
    this.queryParameters,
    this.body,
    this.bodyType,
    this.preRequestScript,
    this.postRequestScript,
    this.scripts,
    this.historyId,
    this.description,
    this.variables,
    this.assertions,
    this.statusCode,
    this.encryptedKey,
  });

  // Mapping from Domain Model
  factory NodeEntity.fromModel(Node node, String collectionId) {
    if (node is RequestNode) {
      return NodeEntity(
        uid: node.id,
        collectionId: collectionId,
        parentId: node.parentId,
        name: node.name,
        type: node.type.name,
        method: node.method,
        requestType: node.requestType.name,
        sortOrder: node.sortOrder,
        url: node.url,
        // body not available in RequestNode, set null (repo must preserve it)
        body: null,
        bodyType: node.reqConfig.bodyType,
        preRequestScript: node.reqConfig.preRequestScript,
        postRequestScript: node.reqConfig.postRequestScript,
        scripts: node.reqConfig.testScript,
        statusCode: node.statusCode,
        headers: node.reqConfig.headers.map((e) => e.toMap()).toList(),
        auth: node.reqConfig.auth.toMap(),
        queryParameters: node.reqConfig.queryParameters
            .map((e) => e.toMap())
            .toList(),
        description: node.reqConfig.description,

        historyId: node.reqConfig.historyId,
        assertions: node.reqConfig.assertions.map((e) => e.toMap()).toList(),
      );
    } else if (node is FolderNode) {
      return NodeEntity(
        uid: node.id,
        collectionId: collectionId,
        parentId: node.parentId,
        name: node.name,
        type: node.type.name,
        sortOrder: node.sortOrder,
        // Variables is List<KeyValueItem> -> List<Map>
        variables: node.folderConfig.variables.map((e) => e.toMap()).toList(),
        headers: node.folderConfig.headers.map((e) => e.toMap()).toList(),
        auth: node.folderConfig.auth.toMap(),
        description: node.folderConfig.description,
        preRequestScript: node.folderConfig.preRequestScript,
        postRequestScript: node.folderConfig.postRequestScript,

        scripts: node.folderConfig.testScript,
        assertions: node.folderConfig.assertions.map((e) => e.toMap()).toList(),
        encryptedKey: node.folderConfig.encryptedKey,
      );
    }
    throw UnimplementedError("Unknown node type");
  }

  // To Domain Model
  Node toModel() {
    if (type == NodeType.folder.name) {
      return FolderNode(
        id: uid,
        parentId: parentId,
        name: name,
        sortOrder: sortOrder,
        config: FolderNodeConfig(
          isDetailLoaded: true,
          description: description ?? '',
          headers: headers?.map((e) => KeyValueItem.fromMap(e)).toList() ?? [],
          auth: auth != null ? AuthData.fromMap(auth!) : const AuthData(),
          variables:
              variables?.map((e) => KeyValueItem.fromMap(e)).toList() ?? [],
          preRequestScript: preRequestScript,
          postRequestScript: postRequestScript,

          testScript: scripts,
          assertions:
              assertions?.map((e) => AssertionDefinition.fromMap(e)).toList() ??
              [],
          encryptedKey: encryptedKey,
        ),
      );
    } else {
      return RequestNode(
        id: uid,
        parentId: parentId,
        name: name,
        sortOrder: sortOrder,
        method: method ?? 'GET',
        url: url ?? '',
        statusCode: statusCode,
        requestType: RequestType.values.firstWhere(
          (e) => e.name == requestType,
          orElse: () => RequestType.http,
        ),
        config: RequestNodeConfig(
          isDetailLoaded: true,
          description: description ?? '',
          headers: headers?.map((e) => KeyValueItem.fromMap(e)).toList() ?? [],
          auth: auth != null ? AuthData.fromMap(auth!) : const AuthData(),
          queryParameters:
              queryParameters?.map((e) => KeyValueItem.fromMap(e)).toList() ??
              [],
          bodyType: bodyType,
          preRequestScript: preRequestScript,
          postRequestScript: postRequestScript,

          testScript: scripts,
          historyId: historyId,
          assertions:
              assertions?.map((e) => AssertionDefinition.fromMap(e)).toList() ??
              [],
        ),
      );
    }
  }
}

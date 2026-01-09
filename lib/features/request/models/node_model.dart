import 'package:flutter/widgets.dart';
import '../../../core/models/models.dart';

enum NodeType { folder, request }

enum DropSlot { top, center, bottom }

abstract class Node<T extends NodeConfig> {
  // Identity (Immutable)
  final String id;
  final String? parentId;
  final String name;
  final NodeType type;
  final int sortOrder;

  // The Configuration (Reference is final, contents are mutable)
  final T config;

  // Runtime Links (Mutable for tree traversal)

  Node({
    required this.id,
    required this.parentId,
    required this.name,
    required this.type,
    required this.config,
    this.sortOrder = 0,
  });

  // --- Helpers ---
  static List<KeyValueItem> parseKeyValueItems(dynamic source) {
    if (source == null || source == '') return [];
    return (source as List)
        .map((e) => KeyValueItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // --- Factory ---
  static Node<NodeConfig> fromMap(Map<String, dynamic> map) {
    if (map['type'] == NodeType.folder.toString()) {
      return FolderNode.fromMap(map);
    } else {
      return RequestNode.fromMap(map);
    }
  }

  // Hydrate: Populates the EXISTING config object
  void hydrate(Map<String, dynamic> details);

  Map<String, dynamic> toMap();

  // Basic copyWith for renaming/moving (creates new Node shell, shares Config)
  Node<T> copyWith({
    String? id,
    String? name,
    String? parentId,
    bool forceNullParent = false, // to set null parentId
    T? config,
    int? sortOrder,
  });

  @override
  String toString() {
    return ':::Node:::\n  id: $id\n  name: $name\n  type: $type\n  parentId: $parentId\n  config: $config\n';
  }
}

// --- FOLDER NODE ---
class FolderNode extends Node<FolderNodeConfig> {
  final List<String> children;

  FolderNode({
    required super.id,
    required super.parentId,
    required super.name,
    required super.config, // Specific Type
    required super.sortOrder,
    this.children = const [],
  }) : super(type: NodeType.folder);

  // Getter helper to avoid casting 'config' manually
  FolderNodeConfig get folderConfig => config;

  @override
  void hydrate(Map<String, dynamic> details) {
    // 1. Update fields inside the existing config object
    folderConfig.description = details['description'] ?? '';
    folderConfig.headers = Node.parseKeyValueItems(details['headers']);

    if (details['auth'] is Map) {
      folderConfig.auth = AuthData.fromMap(
        details['auth'] as Map<String, dynamic>,
      );
    } else {
      folderConfig.auth = const AuthData();
    }

    folderConfig.variables = Node.parseKeyValueItems(details['variables']);

    // 2. Mark as loaded
    folderConfig.isDetailLoaded = true;

    // Note: No return value needed. References to this node now see new data.
  }

  factory FolderNode.fromMap(Map<String, dynamic> map) {
    final bool hasDetails = map.containsKey('headers');

    return FolderNode(
      id: map['id'],
      parentId: map['parent_id'],
      name: map['name'],
      sortOrder: map['sort_order'] ?? 0,
      config: FolderNodeConfig(
        isDetailLoaded: hasDetails,
        description: map['description'] ?? '',
        // If hasDetails is true, parse them. If false, empty defaults.
        headers: hasDetails ? Node.parseKeyValueItems(map['headers']) : [],
        auth: (hasDetails && map['auth'] != null)
            ? AuthData.fromMap(map['auth'])
            : const AuthData(),
        variables: hasDetails ? Node.parseKeyValueItems(map['variables']) : [],
      ),
    );
  }

  @override
  FolderNode copyWith({
    String? name,
    String? parentId,
    bool forceNullParent = false,
    FolderNodeConfig? config,
    List<String>? children,
    int? sortOrder,
    String? id,
  }) {
    return FolderNode(
      sortOrder: sortOrder ?? this.sortOrder,
      id: id ?? this.id,
      parentId: forceNullParent ? null : (parentId ?? this.parentId),
      name: name ?? this.name,
      config: config ?? folderConfig, // Share the same config object
      children: children ?? this.children,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'name': name,
      'type': NodeType.folder.toString(),
      'sort_order': sortOrder,
      // Delegate detailed fields to the config object
      'description': folderConfig.description,
      'headers': folderConfig.headers.map((e) => e.toMap()).toList(),
      'auth': folderConfig.auth.toMap(),
      'variables': folderConfig.variables.map((e) => e.toMap()).toList(),
    };
  }

  @override
  String toString() {
    return ':::Node:::\n  id: $id\n  name: $name\n  type: $type\n  children: ${children.length}\n  parentId: $parentId\n  config: $config\n';
  }
}

// --- COLLECTION NODE ---
class CollectionNode extends FolderNode {
  final CollectionModel collection;

  CollectionNode({
    required this.collection,
    required super.config,
    super.children = const [],
  }) : super(
         id: collection.id,
         parentId: null,
         name: collection.name,
         sortOrder: -1,
       );

  @override
  CollectionNode copyWith({
    String? name,
    String? parentId,
    bool forceNullParent = false,
    FolderNodeConfig? config,
    List<String>? children,
    int? sortOrder,
    String? id,
    CollectionModel? collection,
  }) {
    // If name changes, update collection model too
    final newCollection = (collection ?? this.collection).copyWith(name: name);

    return CollectionNode(
      collection: newCollection,
      config: config ?? this.config,
      children: children ?? this.children,
    );
  }
}

enum RequestType { http, ws, grpc }

// --- REQUEST NODE ---
class RequestNode extends Node<RequestNodeConfig> {
  final String method;
  final String url;
  final int? statusCode;
  final RequestType requestType;

  RequestNode({
    required super.id,
    required super.parentId,
    required super.name,
    required super.config,
    required this.statusCode,
    required super.sortOrder,
    this.method = 'GET',
    this.url = '',
    this.requestType = RequestType.http,
  }) : super(type: NodeType.request);

  RequestNodeConfig get reqConfig => config;

  @override
  void hydrate(Map<String, dynamic> details) {
    config.description = details['description'] ?? '';
    config.headers = Node.parseKeyValueItems(details['headers']);

    if (details['auth'] is Map) {
      config.auth = AuthData.fromMap(details['auth'] as Map<String, dynamic>);
    } else {
      config.auth = const AuthData();
    }

    config.queryParameters = Node.parseKeyValueItems(
      details['query_parameters'],
    );
    config.bodyType = details['body_type'];
    config.scripts = details['scripts'];
    config.historyId = details['history_id'];
    config.isDetailLoaded = true;
  }

  factory RequestNode.fromMap(Map<String, dynamic> map) {
    final bool hasDetails = map.containsKey('headers');
    debugPrint(
      "FromMap RequestNode hasDetails: $hasDetails for id: ${map['id']},query params: ${map['query_parameters']}",
    );
    // print call stack
    // debugPrint(StackTrace.current.toString());
    return RequestNode(
      id: map['id'],
      requestType: RequestType.values.firstWhere(
        (e) => e.toString() == (map['request_type'] ?? 'RequestType.http'),
        orElse: () => RequestType.http,
      ),
      method: map['method'] ?? 'GET',
      url: map['url'] ?? '',
      parentId: map['parent_id'],
      name: map['name'],
      statusCode: map['status_code'],
      sortOrder: map['sort_order'] ?? 0,
      config: RequestNodeConfig(
        isDetailLoaded: hasDetails,
        description: map['description'] ?? '',
        headers: hasDetails ? Node.parseKeyValueItems(map['headers']) : [],
        auth: (hasDetails && map['auth'] != null)
            ? AuthData.fromMap(map['auth'])
            : const AuthData(),
        queryParameters: hasDetails
            ? Node.parseKeyValueItems(map['query_parameters'])
            : [],
        bodyType: map['body_type'],
        scripts: map['scripts'],
        historyId: map['history_id'],
      ),
    );
  }

  @override
  RequestNode copyWith({
    String? id,
    String? name,
    String? parentId,
    bool forceNullParent = false, // to set null parentId
    RequestNodeConfig? config,
    int? sortOrder,
    RequestType? requestType,
    String? method,
    String? url,
    int? statusCode,
  }) {
    return RequestNode(
      id: id ?? this.id,
      statusCode: statusCode ?? this.statusCode,
      parentId: forceNullParent ? null : (parentId ?? this.parentId),
      name: name ?? this.name,
      config: config ?? reqConfig,
      requestType: requestType ?? this.requestType,
      method: method ?? this.method,
      url: url ?? this.url,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'name': name,
      'sort_order': sortOrder,
      'method': method,
      'url': url,
      'type': NodeType.request.toString(),
      'status_code': statusCode,
      // config fields
      'description': reqConfig.description,
      'headers': reqConfig.headers.map((e) => e.toMap()).toList(),
      'auth': reqConfig.auth.toMap(),
      'request_type': requestType.toString(),
      'query_parameters': reqConfig.queryParameters
          .map((e) => e.toMap())
          .toList(),
      'body_type': reqConfig.bodyType,
      'scripts': reqConfig.scripts,
    };
  }

  @override
  String toString() {
    return '''RequestNode(
  id: $id,
  name: $name,
  type: $type,
  parentId: $parentId,
  method: $method,
  url: $url,
  requestType: $requestType,
  lastStatusCode: $statusCode,
  sortOrder: $sortOrder,
  config: $config,
    )''';
  }
}

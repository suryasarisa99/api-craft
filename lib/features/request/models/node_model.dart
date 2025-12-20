import 'dart:convert';
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
  static List<KeyValueItem> parseHeaders(dynamic jsonStr) {
    if (jsonStr == null || jsonStr == '') return [];
    try {
      final List list = jsonDecode(jsonStr);
      return list.map((e) => KeyValueItem.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
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
    folderConfig.headers = Node.parseHeaders(details['headers']);
    folderConfig.auth = details['auth'] != null
        ? AuthData.fromMap(jsonDecode(details['auth']))
        : const AuthData();
    folderConfig.variables = Node.parseHeaders(details['variables']);

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
        headers: hasDetails ? Node.parseHeaders(map['headers']) : [],
        auth: (hasDetails && map['auth'] != null)
            ? AuthData.fromMap(jsonDecode(map['auth']))
            : const AuthData(),
        variables: hasDetails ? Node.parseHeaders(map['variables']) : [],
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
      'headers': jsonEncode(
        folderConfig.headers.map((e) => e.toMap()).toList(),
      ),
      'auth': jsonEncode(folderConfig.auth.toMap()),
      'variables': jsonEncode(
        folderConfig.variables.map((e) => e.toMap()).toList(),
      ),
    };
  }

  @override
  String toString() {
    return ':::Node:::\n  id: $id\n  name: $name\n  type: $type\n  children: ${children.length}\n  parentId: $parentId\n  config: $config\n';
  }
}

enum RequestType { http, wc }

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
    config.headers = Node.parseHeaders(details['headers']);
    config.auth = details['auth'] != null
        ? AuthData.fromMap(jsonDecode(details['auth']))
        : const AuthData();
    config.queryParameters = Node.parseHeaders(details['query_parameters']);
    config.bodyType = details['body_type'];

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
        headers: hasDetails ? Node.parseHeaders(map['headers']) : [],
        auth: (hasDetails && map['auth'] != null)
            ? AuthData.fromMap(jsonDecode(map['auth']))
            : const AuthData(),
        queryParameters: hasDetails
            ? Node.parseHeaders(map['query_parameters'])
            : [],
        bodyType: map['body_type'],
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
      'headers': jsonEncode(reqConfig.headers.map((e) => e.toMap()).toList()),
      'auth': jsonEncode(reqConfig.auth.toMap()),
      'request_type': requestType.toString(),
      'query_parameters': jsonEncode(
        reqConfig.queryParameters.map((e) => e.toMap()).toList(),
      ),
      'body_type': reqConfig.bodyType,
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

// import 'dart:convert';
// import 'package:uuid/uuid.dart';

// enum NodeType { folder, request }

// enum DropSlot { top, center, bottom }

// final uuid = Uuid();

// // ---  Basic Key-Value Model (Supports Duplicates & Enabled State) ---
// class KeyValueItem {
//   final String id;
//   String key;
//   String value;
//   bool isEnabled;

//   KeyValueItem({
//     String? id,
//     this.key = '',
//     this.value = '',
//     this.isEnabled = true,
//   }) : id = id ?? uuid.v4();

//   // For Database serialization
//   Map<String, dynamic> toMap() => {
//     'id': id,
//     'key': key,
//     'value': value,
//     'isEnabled': isEnabled,
//   };

//   factory KeyValueItem.fromMap(Map<String, dynamic> map) => KeyValueItem(
//     id: map['id'],
//     key: map['key'],
//     value: map['value'],
//     isEnabled: map['isEnabled'],
//   );

//   //copy with
//   KeyValueItem copyWith({String? key, String? value, bool? isEnabled}) {
//     return KeyValueItem(
//       id: id,
//       key: key ?? this.key,
//       value: value ?? this.value,
//       isEnabled: isEnabled ?? this.isEnabled,
//     );
//   }
// }

// enum AuthType { inherit, noAuth, basic, bearer, apiKey }

// class AuthData {
//   final AuthType type;
//   final String token;
//   final String username;
//   final String password;

//   const AuthData({
//     this.type = AuthType.inherit,
//     this.token = '',
//     this.username = '',
//     this.password = '',
//   });

//   factory AuthData.fromMap(Map<String, dynamic> map) => AuthData(
//     type: AuthType.values[map['type'] ?? 0],
//     token: map['token'] ?? '',
//     username: map['username'] ?? '',
//     password: map['password'] ?? '',
//   );

//   Map<String, dynamic> toMap() => {
//     'type': type.index,
//     'token': token,
//     'username': username,
//     'password': password,
//   };

//   AuthData copyWith({
//     AuthType? type,
//     String? token,
//     String? username,
//     String? password,
//   }) {
//     return AuthData(
//       type: type ?? this.type,
//       token: token ?? this.token,
//       username: username ?? this.username,
//       password: password ?? this.password,
//     );
//   }
// }

// abstract class Node {
//   final String id;
//   final String? parentId;
//   final String name;
//   final NodeType type;
//   final String description;
//   final List<KeyValueItem> headers;
//   final AuthData auth;

//   // Runtime State
//   Node? parent;
//   final bool isDetailLoaded;

//   Node({
//     required this.id,
//     required this.parentId,
//     required this.name,
//     required this.type,
//     this.description = '',
//     this.headers = const [],
//     this.auth = const AuthData(),
//     this.parent,
//     this.isDetailLoaded = false, // Default to false
//   });

//   // Helper: Only parse if the string exists and is not empty
//   static List<KeyValueItem> parseHeaders(dynamic jsonStr) {
//     if (jsonStr == null || jsonStr == '') return [];
//     try {
//       final List list = jsonDecode(jsonStr);
//       return list.map((e) => KeyValueItem.fromMap(e)).toList();
//     } catch (_) {
//       return [];
//     }
//   }

//   factory Node.fromMap(Map<String, dynamic> map) {
//     if (map['type'] == NodeType.folder.toString()) {
//       return FolderNode.fromMap(map);
//     } else {
//       return RequestNode.fromMap(map);
//     }
//   }

//   Node copyWith();
//   Map<String, dynamic> toMap();
// }
// abstract class NodeConfig{
//   List<KeyValueItem> headers;
//   AuthData auth;
//   String description;
//   bool isLoaded;

//   NodeConfig({
//     this.headers = const [],
//     this.auth = const AuthData(),
//     this.description = '',
//     this.isLoaded = false,
//   });
// }

// class FolderNode extends Node {
//   final List<KeyValueItem> variables;
//   final List<Node> children;

//   FolderNode({
//     required super.id,
//     required super.parentId,
//     required super.name,
//     super.description,
//     super.headers,
//     super.auth,
//     super.parent,
//     super.isDetailLoaded,
//     this.variables = const [],
//     List<Node>? children,
//   }) : children = children ?? [],
//        super(type: NodeType.folder);

//   // FolderNode hydrate(Map<String, dynamic> details) {
//   //   return copyWith(
//   //     description: details['description'],
//   //     // Parse JSON strings from DB
//   //     headers: FileNode.parseHeaders(details['headers']),
//   //     auth: details['auth'] != null
//   //         ? AuthData.fromMap(jsonDecode(details['auth']))
//   //         : const AuthData(),
//   //     variables: FileNode.parseHeaders(details['variables']),
//   //     isDetailLoaded: true, // IMPORTANT: Mark as loaded
//   //   );
//   // }
//   void hydrate(Map<String, dynamic> details) {
//     // We update the content INSIDE the existing object
//     config.headers = Node.parseHeaders(details['headers']);
//     config.auth = ...;
//     config.isLoaded = true;
//     // We did NOT use copyWith, so 'this' reference hasn't changed.
//     // All children pointing to 'this' immediately see the new data.
//   }

//   factory FolderNode.fromMap(Map<String, dynamic> map) {
//     // LAZY LOADING CHECK: Do we have the heavy data?
//     final bool hasDetails = map.containsKey('headers');

//     return FolderNode(
//       id: map['id'],
//       parentId: map['parent_id'],
//       name: map['name'],
//       description: map['description'] ?? '',
//       // Only parse if present, otherwise empty defaults
//       headers: hasDetails ? Node.parseHeaders(map['headers']) : [],
//       auth: (hasDetails && map['auth'] != null)
//           ? AuthData.fromMap(jsonDecode(map['auth']))
//           : const AuthData(),
//       variables: hasDetails ? Node.parseHeaders(map['variables']) : [],
//       isDetailLoaded: hasDetails,
//     );
//   }

//   @override
//   FolderNode copyWith({
//     String? name,
//     String? description,
//     List<KeyValueItem>? headers,
//     AuthData? auth,
//     List<KeyValueItem>? variables,
//     bool? isDetailLoaded,
//   }) {
//     return FolderNode(
//       id: id,
//       parentId: parentId,
//       parent: parent,
//       name: name ?? this.name,
//       description: description ?? this.description,
//       headers: headers ?? this.headers,
//       auth: auth ?? this.auth,
//       variables: variables ?? this.variables,
//       isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
//       children: children,
//     );
//   }

//   @override
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'parent_id': parentId,
//       'name': name,
//       'type': NodeType.folder.toString(),
//       'description': description,
//       'headers': jsonEncode(headers.map((e) => e.toMap()).toList()),
//       'auth': jsonEncode(auth.toMap()),
//       'variables': jsonEncode(variables.map((e) => e.toMap()).toList()),
//     };
//   }
// }

// class RequestNode extends Node {
//   final String method;
//   final String url;
//   final String body;

//   RequestNode({
//     required super.id,
//     required super.parentId,
//     required super.name,
//     super.description,
//     super.headers,
//     super.auth,
//     super.parent,
//     super.isDetailLoaded,
//     this.method = 'GET',
//     this.url = '',
//     this.body = '',
//   }) : super(type: NodeType.request);

//   RequestNode hydrate(Map<String, dynamic> details) {
//     return copyWith(
//       description: details['description'],
//       // Parse JSON strings from DB
//       headers: Node.parseHeaders(details['headers']),
//       auth: details['auth'] != null
//           ? AuthData.fromMap(jsonDecode(details['auth']))
//           : const AuthData(),
//       isDetailLoaded: true, // IMPORTANT: Mark as loaded
//     );
//   }

//   factory RequestNode.fromMap(Map<String, dynamic> map) {
//     final bool hasDetails = map.containsKey('headers');

//     return RequestNode(
//       id: map['id'],
//       parentId: map['parent_id'],
//       name: map['name'],
//       description: map['description'] ?? '',
//       // FIXED: Using hasDetails check and AuthData.fromMap
//       headers: hasDetails ? Node.parseHeaders(map['headers']) : [],
//       auth: (hasDetails && map['auth'] != null)
//           ? AuthData.fromMap(jsonDecode(map['auth']))
//           : const AuthData(),
//       method: map['method'] ?? 'GET',
//       url: map['url'] ?? '',
//       body: map['body'] ?? '',
//       isDetailLoaded: hasDetails,
//     );
//   }

//   @override
//   RequestNode copyWith({
//     String? name,
//     String? description,
//     List<KeyValueItem>? headers,
//     AuthData? auth,
//     String? method,
//     String? url,
//     String? body,
//     bool? isDetailLoaded,
//   }) {
//     return RequestNode(
//       id: id,
//       parentId: parentId,
//       parent: parent,
//       name: name ?? this.name,
//       description: description ?? this.description,
//       headers: headers ?? this.headers,
//       auth: auth ?? this.auth,
//       method: method ?? this.method,
//       url: url ?? this.url,
//       body: body ?? this.body,
//       isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
//     );
//   }

//   @override
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'parent_id': parentId,
//       'name': name,
//       'type': NodeType.request.toString(),
//       'description': description,
//       'headers': jsonEncode(
//         headers.map((e) => e.toMap()).toList(),
//       ), // FIXED: map toMap()
//       'auth': jsonEncode(auth.toMap()), // FIXED: toMap()
//       'method': method,
//       'url': url,
//       'body': body,
//     };
//   }
// }

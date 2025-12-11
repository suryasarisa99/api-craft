import 'package:uuid/uuid.dart';

abstract class NodeConfig {
  List<KeyValueItem> headers;
  AuthData auth;
  String description;
  bool isDetailLoaded;

  NodeConfig({
    List<KeyValueItem>? headers,
    this.auth = const AuthData(),
    this.description = '',
    this.isDetailLoaded = false,
  }) : headers = headers ?? [];

  NodeConfig copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    String? description,
    bool? isDetailLoaded,
  });
  @override
  String toString() {
    return ':::NodeConfig:::\n  description: $description\n  headers: ${headers.length}\n isDetailLoaded: $isDetailLoaded\n';
  }
}

class FolderNodeConfig extends NodeConfig {
  List<KeyValueItem> variables;

  FolderNodeConfig({
    super.headers,
    super.auth,
    super.description,
    super.isDetailLoaded,
    List<KeyValueItem>? variables,
  }) : variables = variables ?? [];

  FolderNodeConfig.empty() : variables = [], super();

  @override
  FolderNodeConfig copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    String? description,
    bool? isDetailLoaded,
    List<KeyValueItem>? variables,
  }) {
    return FolderNodeConfig(
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
      description: description ?? this.description,
      isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
      variables: variables ?? this.variables,
    );
  }
}

class RequestNodeConfig extends NodeConfig {
  String method;
  String url;
  String body;

  RequestNodeConfig({
    super.headers,
    super.auth,
    super.description,
    super.isDetailLoaded,
    this.method = 'GET',
    this.url = '',
    this.body = '',
  });

  RequestNodeConfig.empty() : method = 'GET', url = '', body = '', super();

  @override
  RequestNodeConfig copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    String? description,
    bool? isDetailLoaded,
    String? method,
    String? url,
    String? body,
  }) {
    return RequestNodeConfig(
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
      description: description ?? this.description,
      isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
      method: method ?? this.method,
      url: url ?? this.url,
      body: body ?? this.body,
    );
  }
}

final uuid = Uuid();

class KeyValueItem {
  final String id;
  String key;
  String value;
  bool isEnabled;

  KeyValueItem({
    String? id,
    this.key = '',
    this.value = '',
    this.isEnabled = true,
  }) : id = id ?? uuid.v4();

  factory KeyValueItem.fromMap(Map<String, dynamic> map) => KeyValueItem(
    id: map['id'],
    key: map['key'] ?? '',
    value: map['value'] ?? '',
    isEnabled: map['isEnabled'] ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'key': key,
    'value': value,
    'isEnabled': isEnabled,
  };

  // Helper Copy for editing in UI before saving
  KeyValueItem copyWith({String? key, String? value, bool? isEnabled}) {
    return KeyValueItem(
      id: id,
      key: key ?? this.key,
      value: value ?? this.value,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

enum AuthType { inherit, noAuth, basic, bearer, apiKey }

class AuthData {
  final AuthType type;
  final String token;
  final String username;
  final String password;

  const AuthData({
    this.type = AuthType.inherit,
    this.token = '',
    this.username = '',
    this.password = '',
  });

  factory AuthData.fromMap(Map<String, dynamic> map) => AuthData(
    type: AuthType.values[map['type'] ?? 0],
    token: map['token'] ?? '',
    username: map['username'] ?? '',
    password: map['password'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'type': type.index,
    'token': token,
    'username': username,
    'password': password,
  };

  AuthData copyWith({
    AuthType? type,
    String? token,
    String? username,
    String? password,
  }) {
    return AuthData(
      type: type ?? this.type,
      token: token ?? this.token,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

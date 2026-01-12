import 'package:nanoid/nanoid.dart';
import '../../../core/models/models.dart';

abstract class NodeConfig {
  List<KeyValueItem> headers;
  AuthData auth;
  String description;
  bool isDetailLoaded;
  String? preRequestScript;
  String? postRequestScript;
  String? testScript;

  NodeConfig({
    List<KeyValueItem>? headers,
    this.auth = const AuthData(),
    this.description = '',
    this.isDetailLoaded = false,
    this.preRequestScript,
    this.postRequestScript,
    this.testScript,
  }) : headers = headers ?? [];

  NodeConfig copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    String? description,
    bool? isDetailLoaded,
    String? preRequestScript,
    String? postRequestScript,
    String? testScript,
  });
  @override
  String toString() {
    return ':::NodeConfig:::\n  description: $description\n  headers: ${headers.length}\n isDetailLoaded: $isDetailLoaded\n';
  }

  NodeConfig clone();
}

class FolderNodeConfig extends NodeConfig {
  List<KeyValueItem> variables;

  FolderNodeConfig({
    super.headers,
    super.auth,
    super.description,
    super.isDetailLoaded,
    super.preRequestScript,
    super.postRequestScript,
    super.testScript,
    List<KeyValueItem>? variables,
  }) : variables = variables ?? [];

  FolderNodeConfig.empty() : variables = [], super();

  @override
  FolderNodeConfig copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    String? description,
    bool? isDetailLoaded,
    String? preRequestScript,
    String? postRequestScript,
    String? testScript,
    List<KeyValueItem>? variables,
  }) {
    return FolderNodeConfig(
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
      description: description ?? this.description,
      isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
      preRequestScript: preRequestScript ?? this.preRequestScript,
      postRequestScript: postRequestScript ?? this.postRequestScript,
      testScript: testScript ?? this.testScript,
      variables: variables ?? this.variables,
    );
  }

  @override
  FolderNodeConfig clone() {
    return FolderNodeConfig(
      headers: List<KeyValueItem>.from(headers),
      auth: auth.clone(),
      description: description,
      isDetailLoaded: isDetailLoaded,
      preRequestScript: preRequestScript,
      postRequestScript: postRequestScript,
      testScript: testScript,
      variables: List<KeyValueItem>.from(variables),
    );
  }
}

class RequestNodeConfig extends NodeConfig {
  List<KeyValueItem> queryParameters;
  String? bodyType;
  String? historyId;

  RequestNodeConfig({
    super.headers,
    super.auth,
    super.description,
    super.isDetailLoaded,
    super.preRequestScript,
    super.postRequestScript,
    super.testScript,
    required this.queryParameters,
    this.bodyType,
    this.historyId,
  });

  RequestNodeConfig.empty() : queryParameters = [], bodyType = null, super();

  @override
  RequestNodeConfig copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    String? description,
    bool? isDetailLoaded,
    String? method,
    String? url,
    List<KeyValueItem>? queryParameters,
    String? bodyType,
    String? preRequestScript,
    String? postRequestScript,
    String? testScript,
    String? historyId,

    // force historyId to null
    bool forceNullHistoryId = false,
  }) {
    return RequestNodeConfig(
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      bodyType: bodyType ?? this.bodyType,
      preRequestScript: preRequestScript ?? this.preRequestScript,
      postRequestScript: postRequestScript ?? this.postRequestScript,
      testScript: testScript ?? this.testScript,
      auth: auth ?? this.auth,
      description: description ?? this.description,
      isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
      historyId: forceNullHistoryId ? null : historyId ?? this.historyId,
    );
  }

  @override
  RequestNodeConfig clone() {
    return RequestNodeConfig(
      headers: List<KeyValueItem>.from(headers),
      auth: auth.clone(),
      description: description,
      isDetailLoaded: isDetailLoaded,
      queryParameters: List<KeyValueItem>.from(queryParameters),
      bodyType: bodyType,
      preRequestScript: preRequestScript,
      postRequestScript: postRequestScript,
      testScript: testScript,
      historyId: historyId,
    );
  }
}

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
  }) : id = id ?? nanoid(8);

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

class FormDataItem extends KeyValueItem {
  final String type; // 'text' or 'file'
  final String? filePath;
  final String? fileName;
  final String? contentType;

  FormDataItem({
    super.id,
    super.key,
    super.value,
    super.isEnabled,
    this.type = 'text',
    this.filePath,
    this.fileName,
    this.contentType,
  });

  factory FormDataItem.fromMap(Map<String, dynamic> map) {
    return FormDataItem(
      id: map['id'],
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      isEnabled: map['isEnabled'] ?? true,
      type: map['type'] ?? 'text',
      filePath: map['filePath'],
      fileName: map['fileName'],
      contentType: map['contentType'],
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    'type': type,
    'filePath': filePath,
    'fileName': fileName,
    'contentType': contentType,
  };

  @override
  FormDataItem copyWith({
    String? key,
    String? value,
    bool? isEnabled,
    String? type,
    String? filePath,
    String? fileName,
    String? contentType,

    // aditional
    bool resetFilename = false,
  }) {
    return FormDataItem(
      id: id,
      key: key ?? this.key,
      value: value ?? this.value,
      isEnabled: isEnabled ?? this.isEnabled,
      type: type ?? this.type,
      filePath: resetFilename ? null : (filePath ?? this.filePath),
      contentType: contentType ?? this.contentType,
    );
  }
}

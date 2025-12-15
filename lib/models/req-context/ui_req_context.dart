import 'package:api_craft/models/models.dart';

class UiRequestContext {
  final Node node;
  final List<KeyValueItem> inheritedHeaders;
  final AuthData effectiveAuth;
  final Node? authSource;
  final Map<String, VariableValue> allVariables;
  final List<RawHttpResponse>? history;

  UiRequestContext({
    required this.node,
    required this.inheritedHeaders,
    required this.effectiveAuth,
    required this.authSource,
    required this.allVariables,
    this.history,
  });

  factory UiRequestContext.empty(Node node) {
    return UiRequestContext(
      node: node,
      inheritedHeaders: const [],
      effectiveAuth: const AuthData(type: AuthType.noAuth),
      authSource: null,
      allVariables: const {},
    );
  }

  UiRequestContext copyWith({
    Node? node,
    List<KeyValueItem>? inheritedHeaders,
    AuthData? effectiveAuth,
    Node? authSource,
    Map<String, VariableValue>? allVariables,
    List<RawHttpResponse>? history,
  }) {
    return UiRequestContext(
      node: node ?? this.node,
      inheritedHeaders: inheritedHeaders ?? this.inheritedHeaders,
      effectiveAuth: effectiveAuth ?? this.effectiveAuth,
      authSource: authSource ?? this.authSource,
      allVariables: allVariables ?? this.allVariables,
      history: history ?? this.history,
    );
  }
}

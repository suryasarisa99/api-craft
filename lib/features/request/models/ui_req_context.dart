import 'package:api_craft/core/models/models.dart';

class UiRequestContext {
  final Node node;
  final String? body;
  final Map<String, dynamic> bodyData;
  final List<KeyValueItem> inheritedHeaders;
  final AuthData effectiveAuth;
  final Node? authSource;
  final Map<String, VariableValue> inheritVariables;
  final List<RawHttpResponse>? history;
  final bool isLoading;

  UiRequestContext({
    required this.node,
    required this.body,
    required this.bodyData,
    required this.inheritedHeaders,
    required this.effectiveAuth,
    required this.authSource,
    required this.inheritVariables,
    this.history,
    this.isLoading = false,
  });

  factory UiRequestContext.empty(Node node) {
    return UiRequestContext(
      node: node,
      body: '',
      bodyData: const {},
      inheritedHeaders: const [],
      effectiveAuth: const AuthData(type: AuthType.noAuth),
      authSource: null,
      inheritVariables: const {},
      isLoading: true,
    );
  }

  UiRequestContext copyWith({
    Node? node,
    String? body,
    Map<String, dynamic>? bodyData,
    List<KeyValueItem>? inheritedHeaders,
    AuthData? effectiveAuth,
    Node? authSource,
    Map<String, VariableValue>? allVariables,
    List<RawHttpResponse>? history,
    bool? isLoading,
  }) {
    return UiRequestContext(
      node: node ?? this.node,
      body: body ?? this.body,
      bodyData: bodyData ?? this.bodyData,
      inheritedHeaders: inheritedHeaders ?? this.inheritedHeaders,
      effectiveAuth: effectiveAuth ?? this.effectiveAuth,
      authSource: authSource ?? this.authSource,
      inheritVariables: allVariables ?? this.inheritVariables,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

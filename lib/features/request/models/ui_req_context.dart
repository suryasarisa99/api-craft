import 'package:api_craft/core/models/models.dart';

class UiRequestContext {
  final Node node;
  final String? body;
  final Map<String, dynamic> bodyData;
  final List<KeyValueItem> inheritedHeaders;
  final AuthData effectiveAuth;
  final Node? authSource;
  final Map<String, VariableValue> allVariables;
  final List<RawHttpResponse>? history;
  final bool isLoading;
  final bool isSending;

  final DateTime? sendStartTime;
  final String? sendError;

  UiRequestContext({
    required this.node,
    required this.body,
    required this.bodyData,
    required this.inheritedHeaders,
    required this.effectiveAuth,
    required this.authSource,
    required this.allVariables,
    this.history,
    this.isLoading = false,
    this.isSending = false,
    this.sendStartTime,
    this.sendError,
  });

  factory UiRequestContext.empty(Node node) {
    return UiRequestContext(
      node: node,
      body: '',
      bodyData: const {},
      inheritedHeaders: const [],
      effectiveAuth: const AuthData(type: AuthType.noAuth),
      authSource: null,
      allVariables: const {},
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
    bool? isSending,
    DateTime? sendStartTime,
    String? sendError,
  }) {
    return UiRequestContext(
      node: node ?? this.node,
      body: body ?? this.body,
      bodyData: bodyData ?? this.bodyData,
      inheritedHeaders: inheritedHeaders ?? this.inheritedHeaders,
      effectiveAuth: effectiveAuth ?? this.effectiveAuth,
      authSource: authSource ?? this.authSource,
      allVariables: allVariables ?? this.allVariables,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      sendStartTime: sendStartTime ?? this.sendStartTime,
      sendError: sendError ?? this.sendError,
    );
  }
}

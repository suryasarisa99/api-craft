import 'package:api_craft/http/raw/raw_http_req.dart';

import 'models.dart';

class VariableValue {
  final String sourceId;
  final dynamic value;

  VariableValue(this.sourceId, this.value);
}

class ResolveConfig {
  final Node node;
  final List<KeyValueItem>? inheritedHeaders;
  final Map<String, VariableValue>? allVariables;
  final AuthData? effectiveAuth;
  final Node? effectiveAuthSource;
  final List<RawHttpResponse>? history;

  ResolveConfig({
    required this.node,
    required this.inheritedHeaders,
    this.effectiveAuth,
    this.effectiveAuthSource,
    this.allVariables,
    this.history,
  });

  ResolveConfig.empty(this.node)
    : inheritedHeaders = null,
      effectiveAuth = null,
      effectiveAuthSource = null,
      allVariables = null,
      history = null;

  ResolveConfig copyWith({
    Node? node,
    List<KeyValueItem>? inheritedHeaders,
    AuthData? effectiveAuth,
    Node? effectiveAuthSource,
    Map<String, VariableValue>? allVariables,
    List<RawHttpResponse>? history,
  }) {
    return ResolveConfig(
      node: node ?? this.node,
      inheritedHeaders: inheritedHeaders ?? this.inheritedHeaders,
      effectiveAuth: effectiveAuth ?? this.effectiveAuth,
      effectiveAuthSource: effectiveAuthSource ?? this.effectiveAuthSource,
      allVariables: allVariables ?? this.allVariables,
      history: history ?? this.history,
    );
  }
}

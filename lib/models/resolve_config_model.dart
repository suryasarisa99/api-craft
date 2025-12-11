import 'models.dart';

class ResolveConfig {
  final Node node;
  final List<KeyValueItem>? inheritedHeaders;
  final AuthData? effectiveAuth;
  final Node? effectiveAuthSource;

  ResolveConfig({
    required this.node,
    required this.inheritedHeaders,
    this.effectiveAuth,
    this.effectiveAuthSource,
  });

  ResolveConfig.empty(this.node)
    : inheritedHeaders = null,
      effectiveAuth = null,
      effectiveAuthSource = null;

  ResolveConfig copyWith({
    Node? node,
    List<KeyValueItem>? inheritedHeaders,
    AuthData? effectiveAuth,
    Node? effectiveAuthSource,
  }) {
    return ResolveConfig(
      node: node ?? this.node,
      inheritedHeaders: inheritedHeaders ?? this.inheritedHeaders,
      effectiveAuth: effectiveAuth ?? this.effectiveAuth,
      effectiveAuthSource: effectiveAuthSource ?? this.effectiveAuthSource,
    );
  }
}

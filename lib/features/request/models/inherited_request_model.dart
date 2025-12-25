import 'package:api_craft/core/models/models.dart';

class InheritedRequest {
  final List<KeyValueItem> headers;
  final AuthData auth;
  final Node? authSource;
  final Map<String, VariableValue> variables;

  const InheritedRequest({
    required this.headers,
    required this.auth,
    this.authSource,
    required this.variables,
  });

  const InheritedRequest.empty()
    : headers = const [],
      auth = const AuthData(type: AuthType.noAuth),
      authSource = null,
      variables = const {};

  InheritedRequest copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    Node? authSource,
    Map<String, VariableValue>? variables,
  }) {
    return InheritedRequest(
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
      authSource: authSource ?? this.authSource,
      variables: variables ?? this.variables,
    );
  }
}

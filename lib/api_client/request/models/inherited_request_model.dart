import 'package:api_craft/core/models/models.dart';

class InheritedRequest {
  final List<KeyValueItem> headers;
  final AuthData auth;
  final Node? authSource;
  final Map<String, VariableValue> variables;

  final RequestSettings settings;
  final Node? settingsSource;

  const InheritedRequest({
    required this.headers,
    required this.auth,
    this.authSource,
    required this.variables,
    this.settings = const RequestSettings(),
    this.settingsSource,
  });

  const InheritedRequest.empty()
    : headers = const [],
      auth = const AuthData(type: AuthType.noAuth),
      authSource = null,
      variables = const {},
      settings = const RequestSettings(),
      settingsSource = null;

  InheritedRequest copyWith({
    List<KeyValueItem>? headers,
    AuthData? auth,
    Node? authSource,
    Map<String, VariableValue>? variables,
    RequestSettings? settings,
    Node? settingsSource,
  }) {
    return InheritedRequest(
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
      authSource: authSource ?? this.authSource,
      variables: variables ?? this.variables,
      settings: settings ?? this.settings,
      settingsSource: settingsSource ?? this.settingsSource,
    );
  }
}

import 'package:api_craft/core/models/models.dart';

class ResolvedRequestContext {
  final RequestNode request;
  final Uri uri;
  final dynamic body;
  final List<List<String>> headers;
  final AuthData auth;
  final Map<String, VariableValue> variables;

  ResolvedRequestContext({
    required this.request,
    required this.uri,
    required this.body,
    required this.headers,
    required this.auth,
    required this.variables,
  });
  Map<String, dynamic> toMap() {
    return {
      'uri': uri.toString(),
      'method': request.method,
      'headers': headers.map((e) => {'key': e[0], 'value': e[1]}).toList(),
      'body': body is List<int> ? String.fromCharCodes(body) : body,
      'auth': {
        'type': auth.type.name,
        'username': auth.username,
        'token': auth.token,
      },
      'variables': variables.map((key, value) => MapEntry(key, value.value)),
    };
  }
}

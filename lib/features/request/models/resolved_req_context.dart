import 'package:api_craft/core/models/models.dart';

class ResolvedRequestContext {
  final RequestNode request;
  final Uri uri;
  final String? body;
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
}

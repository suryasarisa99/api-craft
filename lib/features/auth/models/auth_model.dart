import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/dynamic-form/form_input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthType {
  apiKey("API Key", "API Key"),
  awsSignature("AWS v4", "AWS Signature"),
  basic("Basic", "Basic Auth"),
  bearer("Bearer", "Bearer Token"),
  jwtBearer("JWT", "JWT Bearer"),
  oAuth1("OAuth 1", "OAuth 1.0"),
  oAuth2("OAuth 2", "OAuth 2.0"),
  ntlm("NTLM", "NTLM Auth"),
  inherit("Auth", "Inherit from Parent"),
  noAuth("No Auth", "No Authentication");

  final String title;
  final String label;
  const AuthType(this.label, this.title);
}

class CallAuthFunctionArgs {
  // final String contextId;
  final String method;
  final String url;
  final List<List<String>> headers;
  final dynamic values;

  const CallAuthFunctionArgs({
    required this.method,
    required this.url,
    required this.headers,
    required this.values,
  });
}

class Authenticaion {
  final String type;
  final String label;
  final String shortLabel;
  final List<FormInput> args;
  final Function(Ref ref, CallAuthFunctionArgs args) onApply;

  const Authenticaion({
    required this.type,
    required this.label,
    required this.shortLabel,
    required this.args,
    required this.onApply,
  });
}

class AuthData {
  final AuthType type;
  final String token;
  final String username;
  final String password;

  const AuthData({
    this.type = AuthType.inherit,
    this.token = '',
    this.username = '',
    this.password = '',
  });

  factory AuthData.fromMap(Map<String, dynamic> map) => AuthData(
    type: AuthType.values[map['type'] ?? 0],
    token: map['token'] ?? '',
    username: map['username'] ?? '',
    password: map['password'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'type': type.index,
    'token': token,
    'username': username,
    'password': password,
  };

  AuthData copyWith({
    AuthType? type,
    String? token,
    String? username,
    String? password,
  }) {
    return AuthData(
      type: type ?? this.type,
      token: token ?? this.token,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  AuthData clone() {
    return AuthData(
      type: type,
      token: token,
      username: username,
      password: password,
    );
  }
}

import 'dart:async';

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

class AuthResult {
  final List<List<String>>? headers;
  final List<List<String>>? queryParameters;

  const AuthResult({this.headers, this.queryParameters});
}

class Authenticaion {
  final String type;
  final String label;
  final String shortLabel;
  final List<FormInput> args;
  final FutureOr<AuthResult?> Function(Ref ref, CallAuthFunctionArgs args)
  onApply;

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
  final Map<String, dynamic> data;

  const AuthData({this.type = AuthType.inherit, this.data = const {}});

  factory AuthData.fromMap(Map<String, dynamic> map) => AuthData(
    type: AuthType.values[map['type'] ?? 0],
    data: map['authData'] ?? {},
  );

  Map<String, dynamic> toMap() => {'type': type.index, 'authData': data};

  AuthData copyWith({AuthType? type, Map<String, dynamic>? data}) {
    return AuthData(type: type ?? this.type, data: data ?? this.data);
  }

  AuthData clone() {
    return AuthData(type: type, data: data);
  }
}

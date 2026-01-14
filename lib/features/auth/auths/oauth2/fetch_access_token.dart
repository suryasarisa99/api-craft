import 'dart:convert';
import 'package:api_craft/core/network/raw/raw_http_req.dart';
import 'package:api_craft/features/auth/auths/oauth2/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<AccessTokenRawResponse> fetchAccessToken(
  Ref ref,
  TokenStoreArgs args, {
  required String grantType,
  required String accessTokenUrl,
  required String clientId,
  String? clientSecret,
  String? scope,
  String? audience,
  bool credentialsInBody = true,
  List<Map<String, String>> params = const [],
}) async {
  print('[oauth2] Getting access token $accessTokenUrl');

  final Map<String, String> body = {'grant_type': grantType};

  for (final p in params) {
    if (p['value'] != null) {
      body[p['name']!] = p['value']!;
    }
  }

  if (scope != null && scope.isNotEmpty) body['scope'] = scope;
  if (audience != null && audience.isNotEmpty) body['audience'] = audience;

  final List<List<String>> headers = [
    ['User-Agent', 'api_craft'],
    ['Accept', 'application/x-www-form-urlencoded, application/json'],
    ['Content-Type', 'application/x-www-form-urlencoded'],
  ];

  if (credentialsInBody) {
    body['client_id'] = clientId;
    if (clientSecret != null) body['client_secret'] = clientSecret;
  } else {
    // Basic Auth
    final basicAuth = base64Encode(
      utf8.encode('$clientId:${clientSecret ?? ""}'),
    );
    headers.add(['Authorization', 'Basic $basicAuth']);
  }

  // Raw HTTP Request
  final response = await sendRawHttp(
    method: 'POST',
    url: Uri.parse(accessTokenUrl),
    requestId: 'oauth2_token_${DateTime.now().millisecondsSinceEpoch}',
    headers: headers,
    body: Uri(queryParameters: body).query,
  );

  print('[oauth2] Got access token response ${response.statusCode}');

  if (response.statusCode >= 200 && response.statusCode < 300) {
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      // Fallback to query params parsing if json fails (some older Oauth providers)
      jsonBody = Uri.splitQueryString(response.body);
    }

    // If jsonBody is Map
    if (jsonBody is Map<String, dynamic>) {
      final rawResponse = AccessTokenRawResponse.fromMap(jsonBody);
      if (rawResponse.error != null) {
        throw Exception(
          'Failed to fetch access token with ${rawResponse.error}',
        );
      }
      return rawResponse;
    } else {
      // Should technically verify this case
      return AccessTokenRawResponse(
        jsonBody is Map<String, dynamic> ? jsonBody : {},
      );
    }
  } else {
    throw Exception(
      'Failed to fetch access token with status=${response.statusCode} and body=${response.body}',
    );
  }
}

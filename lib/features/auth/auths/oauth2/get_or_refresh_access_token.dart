import 'dart:convert';
import 'package:api_craft/core/network/raw/raw_http_req.dart';
import 'package:api_craft/features/auth/auths/oauth2/store.dart';
import 'package:api_craft/features/auth/auths/oauth2/util.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<AccessToken?> getOrRefreshAccessToken(
  Ref ref,
  TokenStoreArgs tokenArgs, {
  required String accessTokenUrl,
  required String clientId,
  required String clientSecret,
  String? scope,
  bool credentialsInBody = true,
  bool forceRefresh = false,
}) async {
  final token = await OAuth2Store.getToken(ref, tokenArgs);
  if (token == null) return null;

  final isExpired = isTokenExpired(token);

  if (!isExpired && !forceRefresh) {
    return token;
  }

  if (token.response.refreshToken == null) {
    return null;
  }

  // Refresh - Replicating logic from getOrRefreshAccessToken.ts which manually constructs request
  // instead of calling fetchAccessToken to handle 4xx deletion carefully.

  final Map<String, String> body = {
    'grant_type': 'refresh_token',
    'refresh_token': token.response.refreshToken!,
  };

  if (scope != null && scope.isNotEmpty) {
    body['scope'] = scope;
  }

  final List<List<String>> headers = [
    ['User-Agent', 'api_craft'],
    ['Accept', 'application/x-www-form-urlencoded, application/json'],
    ['Content-Type', 'application/x-www-form-urlencoded'],
  ];

  if (credentialsInBody) {
    body['client_id'] = clientId;
    body['client_secret'] = clientSecret;
  } else {
    final basicAuth = base64Encode(utf8.encode('$clientId:$clientSecret'));
    headers.add(['Authorization', 'Basic $basicAuth']);
  }

  try {
    final response = await sendRawHttp(
      method: 'POST',
      url: Uri.parse(accessTokenUrl),
      requestId: 'oauth2_refresh_${DateTime.now().millisecondsSinceEpoch}',
      headers: headers,
      body: Uri(queryParameters: body).query,
    );

    print('[oauth2] Got refresh token response ${response.statusCode}');

    if (response.statusCode >= 400 && response.statusCode < 500) {
      // Client errors (4xx) indicate the refresh token is invalid, expired, or revoked
      // Delete the token and return null to trigger a fresh authorization flow
      debugPrint(
        '[oauth2] Refresh token request failed with client error, deleting token',
      );
      await OAuth2Store.deleteToken(ref, tokenArgs);
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to refresh access token with status=${response.statusCode} and body=${response.body}',
      );
    }

    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      jsonBody = Uri.splitQueryString(response.body);
    }

    if (jsonBody is! Map<String, dynamic>) {
      throw Exception('Invalid response body format');
    }

    if (jsonBody['error'] != null) {
      throw Exception(
        'Failed to fetch access token with ${jsonBody['error']} -> ${jsonBody['error_description']}',
      );
    }

    // New AccessTokenRawResponse merging logic
    final Map<String, dynamic> newMap = Map.from(jsonBody);

    // Assign a new one or keep the old one
    if (!newMap.containsKey('refresh_token') &&
        !newMap.containsKey('refreshToken')) {
      newMap['refresh_token'] = token.response.refreshToken;
    }

    final newResponse = AccessTokenRawResponse.fromMap(newMap);
    await OAuth2Store.storeToken(
      ref,
      args: tokenArgs,
      response: newResponse,
      tokenName: 'access_token',
    );

    return await OAuth2Store.getToken(ref, tokenArgs);
  } catch (e) {
    debugPrint('[oauth2] Refresh error: $e');
    rethrow;
  }
}

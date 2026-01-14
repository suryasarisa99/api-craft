import 'package:api_craft/features/auth/auths/oauth2/store.dart';
import 'package:api_craft/features/auth/auths/oauth2/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

Future<AccessTokenRawResponse> getImplicit(
  Ref ref,
  Map<String, dynamic> args,
) async {
  final contextId = args['contextId'] ?? 'default';
  final authorizationUrlRaw = args['authorizationUrl'] as String;
  final clientId = args['clientId'] as String;
  final redirectUri = args['redirectUri'] as String?;
  final responseType = args['responseType'] as String? ?? 'token';
  final scope = args['scope'] as String?;
  final state = args['state'] as String?;
  final audience = args['audience'] as String?;
  final tokenName = args['tokenName'] as String? ?? 'access_token';

  final tokenArgs = TokenStoreArgs(
    contextId: contextId,
    clientId: clientId,
    accessTokenUrl: '',
    authorizationUrl: authorizationUrlRaw,
  );

  final existingToken = await OAuth2Store.getToken(ref, tokenArgs);
  if (existingToken != null && !isTokenExpired(existingToken)) {
    return existingToken.response;
  }

  // Construct URL
  Uri authorizationUrl;
  try {
    authorizationUrl = Uri.parse(authorizationUrlRaw);
  } catch (e) {
    throw Exception('Invalid authorization URL: $authorizationUrlRaw');
  }

  final params = Map<String, String>.from(authorizationUrl.queryParameters);
  params['response_type'] = 'token';
  params['client_id'] = clientId;
  if (redirectUri != null && redirectUri.isNotEmpty) {
    params['redirect_uri'] = redirectUri;
  }
  if (scope != null && scope.isNotEmpty) params['scope'] = scope;
  if (state != null && state.isNotEmpty) params['state'] = state;
  if (audience != null && audience.isNotEmpty) params['audience'] = audience;

  if (responseType.contains('id_token')) {
    params['nonce'] = (Random().nextInt(900000000) + 100000000).toString();
  }

  authorizationUrl = authorizationUrl.replace(queryParameters: params);

  // Open URL
  debugPrint("Opening Auth URL: $authorizationUrl");
  await launchUrl(authorizationUrl, mode: LaunchMode.externalApplication);

  // For implicit flow, the token is in the hash fragment of the redirect URL.
  // We cannot capture it automatically without a WebView or Deep Linking.

  // If we had the redirected URL (e.g. pasted by user), we could parse it:
  String? callbackUrlStr = args['callbackUrl']; // Hypothetical manual input

  if (callbackUrlStr == null) {
    throw UnimplementedError(
      "Implicit flow requires capturing the redirect URL which is not implemented automatically. Please provide the callback URL manually.",
    );
  }

  // Parse token from callback URL
  Uri callbackUrl = Uri.parse(callbackUrlStr);
  if (callbackUrl.queryParameters.containsKey('error')) {
    throw Exception(
      'Failed to authorize: ${callbackUrl.queryParameters['error']}',
    );
  }

  // Implicit tokens are in the hash
  if (!callbackUrl.hasFragment || callbackUrl.fragment.isEmpty) {
    throw Exception('No fragment found in redirect URL');
  }

  final hashParams = Uri.splitQueryString(callbackUrl.fragment);
  final accessToken = hashParams[tokenName];

  if (accessToken == null) {
    throw Exception('Token not found in redirect URL');
  }

  final response = AccessTokenRawResponse.fromMap(hashParams);

  await OAuth2Store.storeToken(
    ref,
    args: tokenArgs,
    response: response,
    tokenName: tokenName,
  );
  return response;
}

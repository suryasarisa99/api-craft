import 'package:api_craft/features/auth/auths/oauth2/fetch_access_token.dart';
import 'package:api_craft/features/auth/auths/oauth2/get_or_refresh_access_token.dart';
import 'package:api_craft/features/auth/auths/oauth2/store.dart';
import 'package:api_craft/features/auth/auths/oauth2/util.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

Future<AccessTokenRawResponse> getAuthorizationCode(
  Ref ref,
  Map<String, dynamic> args,
) async {
  final contextId = args['contextId'] ?? 'default';
  final authorizationUrlRaw = args['authorizationUrl'] as String;
  final accessTokenUrl = args['accessTokenUrl'] as String;
  final clientId = args['clientId'] as String;
  final clientSecret = args['clientSecret'] as String?;
  final redirectUri = args['redirectUri'] as String?;
  final scope = args['scope'] as String?;
  final state = args['state'] as String?;
  final audience = args['audience'] as String?;
  final tokenName = args['tokenName'] as String? ?? 'access_token';
  final credentialsInBody = args['credentialsInBody'] == true;
  final usePkce = args['usePkce'] == true;

  final tokenArgs = TokenStoreArgs(
    contextId: contextId,
    clientId: clientId,
    accessTokenUrl: accessTokenUrl,
    authorizationUrl: authorizationUrlRaw,
  );

  final existingToken = await getOrRefreshAccessToken(
    ref,
    tokenArgs,
    accessTokenUrl: accessTokenUrl,
    clientId: clientId,
    clientSecret: clientSecret ?? '',
    scope: scope,
    credentialsInBody: credentialsInBody,
  );

  if (existingToken != null) {
    return existingToken.response;
  }

  // Construct URL
  Uri authorizationUrl;
  try {
    authorizationUrl = Uri.parse(authorizationUrlRaw);
  } catch (e) {
    throw Exception('Invalid authorization URL: $authorizationUrlRaw');
  }

  // params map modification
  final queryParams = Map<String, String>.from(
    authorizationUrl.queryParameters,
  );
  queryParams['response_type'] = 'code';
  queryParams['client_id'] = clientId;
  if (redirectUri != null && redirectUri.isNotEmpty) {
    queryParams['redirect_uri'] = redirectUri;
  }
  if (scope != null && scope.isNotEmpty) queryParams['scope'] = scope;
  if (state != null && state.isNotEmpty) queryParams['state'] = state;
  if (audience != null && audience.isNotEmpty) {
    queryParams['audience'] = audience;
  }

  String? codeVerifier;
  if (usePkce) {
    codeVerifier = genPkceCodeVerifier();
    final challenge = pkceCodeChallenge(codeVerifier, defaultPkceMethod);
    queryParams['code_challenge'] = challenge;
    queryParams['code_challenge_method'] = defaultPkceMethod;
  }

  authorizationUrl = authorizationUrl.replace(queryParameters: queryParams);

  debugPrint('[oauth2] Authorizing $authorizationUrl');
  await launchUrl(authorizationUrl, mode: LaunchMode.externalApplication);

  // Here we need to capture the code.
  // Since we cannot automate this easily without deep links, we might check if 'code' was passed in args manually?
  // Or we just throw for now, but the Logic below is implemented.

  String? code;
  if (args['code'] != null) {
    code = args['code'];
  } else {
    // TODO: Implement manual input or callback server
    throw UnimplementedError(
      "Authorization Code capture is not implemented. Please provide the code manually if possible.",
    );
  }

  debugPrint('[oauth2] Code found: $code');

  final params = <Map<String, String>>[
    {'name': 'code', 'value': code!},
  ];

  if (usePkce && codeVerifier != null) {
    params.add({'name': 'code_verifier', 'value': codeVerifier});
  }
  if (redirectUri != null && redirectUri.isNotEmpty) {
    params.add({'name': 'redirect_uri', 'value': redirectUri});
  }

  return storeToken(
    ref,
    tokenArgs,
    await fetchAccessToken(
      ref,
      tokenArgs,
      grantType: 'authorization_code',
      accessTokenUrl: accessTokenUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      scope: scope,
      audience: audience,
      credentialsInBody: credentialsInBody,
      params: params,
    ),
    tokenName: tokenName,
  );
}

// Helper to match storeToken(ctx, tokenArgs, response, tokenName) in TS
Future<AccessTokenRawResponse> storeToken(
  Ref ref,
  TokenStoreArgs args,
  AccessTokenRawResponse response, {
  required String tokenName,
}) async {
  await OAuth2Store.storeToken(
    ref,
    args: args,
    response: response,
    tokenName: tokenName,
  );
  return response;
}

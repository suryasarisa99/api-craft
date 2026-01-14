import 'package:api_craft/features/auth/auths/oauth2/fetch_access_token.dart';
import 'package:api_craft/features/auth/auths/oauth2/get_or_refresh_access_token.dart';
import 'package:api_craft/features/auth/auths/oauth2/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<AccessTokenRawResponse> getPassword(
  Ref ref,
  Map<String, dynamic> args,
) async {
  final contextId = 'default';
  final accessTokenUrl = args['accessTokenUrl'] as String;
  final clientId = args['clientId'] as String;
  final clientSecret = args['clientSecret'] as String?;
  final username = args['username'] as String;
  final password = args['password'] as String;
  final scope = args['scope'] as String?;
  final audience = args['audience'] as String?;
  final credentialsInBody = args['credentialsInBody'] == true;

  final tokenArgs = TokenStoreArgs(
    contextId: contextId,
    clientId: clientId,
    accessTokenUrl: accessTokenUrl,
    authorizationUrl: '',
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

  final response = await fetchAccessToken(
    ref,
    tokenArgs,
    grantType: 'password',
    accessTokenUrl: accessTokenUrl,
    clientId: clientId,
    clientSecret: clientSecret,
    scope: scope,
    audience: audience,
    credentialsInBody: credentialsInBody,
    params: [
      {'name': 'username', 'value': username},
      {'name': 'password', 'value': password},
    ],
  );

  await OAuth2Store.storeToken(
    ref,
    args: tokenArgs,
    response: response,
    tokenName: 'access_token',
  );

  return response;
}

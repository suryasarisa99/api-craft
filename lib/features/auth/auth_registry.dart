import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/auth/auths/auth_apikey.dart';
import 'package:api_craft/features/auth/auths/auth_aws.dart';
import 'package:api_craft/features/auth/auths/auth_basic.dart';
import 'package:api_craft/features/auth/auths/auth_bearer.dart';
import 'package:api_craft/features/auth/auths/auth_jwt.dart';
import 'package:api_craft/features/auth/auths/auth_ntlm.dart';
import 'package:api_craft/features/auth/auths/auth_oauth1.dart';
import 'package:api_craft/features/auth/auths/oauth2/auth_oauth2.dart';

final auths = [
  apiKeyAuth,
  awsV4Auth,
  basicAuth,
  bearerAuth,
  jwtAuth,
  oAuth1,
  oauth2Auth,
  ntlmAuth,
];

Authenticaion? getAuth(AuthType type) {
  switch (type) {
    case AuthType.apiKey:
      return apiKeyAuth;
    case AuthType.awsSignature:
      return awsV4Auth;
    case AuthType.basic:
      return basicAuth;
    case AuthType.bearer:
      return bearerAuth;
    case AuthType.jwtBearer:
      return jwtAuth;
    case AuthType.oAuth1:
      return oAuth1;
    case AuthType.oAuth2:
      return oauth2Auth;
    case AuthType.ntlm:
      return ntlmAuth;
    default:
      return null;
  }
}

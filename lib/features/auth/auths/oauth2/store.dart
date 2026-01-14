import 'dart:convert';

import 'package:api_craft/core/services/app_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoid/nanoid.dart';

class AccessToken {
  final AccessTokenRawResponse response;
  final int? expiresAt;
  AccessToken({required this.response, required this.expiresAt});

  //from map
  factory AccessToken.fromMap(Map<String, dynamic> map) {
    return AccessToken(
      response: AccessTokenRawResponse.fromMap(map['response']),
      expiresAt: map['expiresAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'response': response.toMap(), 'expiresAt': expiresAt};
  }
}

class TokenStoreArgs {
  final String contextId;
  final String clientId;
  final String accessTokenUrl;
  final String authorizationUrl;
  TokenStoreArgs({
    required this.contextId,
    required this.clientId,
    required this.accessTokenUrl,
    required this.authorizationUrl,
  });
}

class AccessTokenRawResponse {
  final Map<String, dynamic> raw;

  AccessTokenRawResponse(this.raw);

  String get accessToken => raw['access_token'] ?? raw['accessToken'];
  String? get idToken => raw['id_token'] ?? raw['idToken'];
  String? get tokenType => raw['token_type'] ?? raw['tokenType'];
  int? get expiresIn => raw['expires_in'] ?? raw['expiresIn'];
  String? get refreshToken => raw['refresh_token'] ?? raw['refreshToken'];
  String? get error => raw['error'];
  String? get errorDescription =>
      raw['error_description'] ?? raw['errorDescription'];
  String? get scope => raw['scope'];

  factory AccessTokenRawResponse.fromMap(Map<String, dynamic> map) {
    return AccessTokenRawResponse(map);
  }

  Map<String, dynamic> toMap() => raw;
}

class OAuth2Store {
  static Future<void> storeToken(
    Ref ref, {
    required TokenStoreArgs args,
    required AccessTokenRawResponse response,
    required String tokenName,
  }) async {
    if ((tokenName == 'access_token' && response.accessToken == null) ||
        (tokenName == 'refresh_token' && response.refreshToken == null)) {
      throw Exception('Token not found in response');
    }
    final expiresAt = response.expiresIn != null
        ? DateTime.now().add(Duration(seconds: response.expiresIn!))
        : null;
    if (expiresAt == null) {
      throw Exception('Expires at not found in response');
    }
    final token = AccessToken(
      response: response,
      expiresAt: expiresAt.millisecondsSinceEpoch,
    );
    AppService.store.setValue(_tokenStoreKey(args), token.toMap());
  }

  static Future<AccessToken?> getToken(Ref ref, TokenStoreArgs args) async {
    final tokenMap = AppService.store.getValue(_tokenStoreKey(args));
    if (tokenMap == null) return null;
    return AccessToken.fromMap(tokenMap);
  }

  static Future<void> deleteToken(Ref ref, TokenStoreArgs args) async {
    return AppService.store.deleteValue(_tokenStoreKey(args));
  }

  static Future<void> resetDataDirKeys(Ref ref, String contextId) async {
    final key = nanoid();
    return AppService.store.setValue(_dataDirStoreKey(contextId), key);
  }

  static Future<String?> getDataDirKey(Ref ref, String contextId) async {
    return AppService.store.getValue(_dataDirStoreKey(contextId));
  }

  static String _tokenStoreKey(TokenStoreArgs args) {
    final bytes = <int>[];

    void add(String? v, {bool stripProtocol = false}) {
      if (v == null) return;
      var s = v.trim();
      if (stripProtocol) {
        s = s.replaceFirst(RegExp(r'^https?:\/\/'), '');
      }
      bytes.addAll(utf8.encode(s));
    }

    add(args.contextId);
    add(args.clientId);
    add(args.accessTokenUrl, stripProtocol: true);
    add(args.authorizationUrl, stripProtocol: true);

    final key = md5.convert(bytes).toString(); // hex
    return 'token::$key';
  }

  static String _dataDirStoreKey(String contextId) {
    return 'data-dir::$contextId';
  }
}

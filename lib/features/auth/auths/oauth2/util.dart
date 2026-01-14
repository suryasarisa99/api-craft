import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:api_craft/features/auth/auths/oauth2/store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

const pkceSha256 = 'S256';
const pkcePlain = 'plain';
const defaultPkceMethod = pkceSha256;

bool isTokenExpired(AccessToken token) {
  if (token.expiresAt == null) return false;
  // Buffer of 10 seconds (Date.now() > token.expiresAt in TS, but here we check milliseconds)
  return DateTime.now().millisecondsSinceEpoch > (token.expiresAt!);
}

String? extractCode(String urlStr, String? redirectUri) {
  Uri url;
  try {
    url = Uri.parse(urlStr);
  } catch (e) {
    return null;
  }

  if (!urlMatchesRedirect(url, redirectUri)) {
    debugPrint('[oauth2] URL does not match redirect origin/path; skipping.');
    return null;
  }

  // Prefer query param; fall back to fragment if query lacks it
  final query = url.queryParameters;
  final queryError = query['error'];
  final queryDesc = query['error_description'];
  final queryUri = query['error_uri'];

  Map<String, String>? hashParams;
  if (url.hasFragment && url.fragment.length > 1) {
    try {
      hashParams = Uri.splitQueryString(url.fragment);
    } catch (_) {}
  }

  final hashError = hashParams?['error'];
  final hashDesc = hashParams?['error_description'];
  final hashUri = hashParams?['error_uri'];

  final error = queryError ?? hashError;
  if (error != null) {
    final desc = queryDesc ?? hashDesc;
    final uri = queryUri ?? hashUri;
    var message = 'Failed to authorize: $error';
    if (desc != null) message += ' ($desc)';
    if (uri != null) message += ' [$uri]';
    throw Exception(message);
  }

  final queryCode = query['code'];
  if (queryCode != null) return queryCode;

  final hashCode = hashParams?['code'];
  if (hashCode != null) return hashCode;

  debugPrint('[oauth2] Code not found');
  return null;
}

bool urlMatchesRedirect(Uri url, String? redirectUrlStr) {
  if (redirectUrlStr == null || redirectUrlStr.isEmpty) return true;

  Uri redirect;
  try {
    redirect = Uri.parse(redirectUrlStr);
  } catch (e) {
    debugPrint('[oauth2] Invalid redirect URI; skipping.');
    return false;
  }

  final sameProtocol = url.scheme == redirect.scheme;
  final sameHost = url.host.toLowerCase() == redirect.host.toLowerCase();

  String normalizePort(Uri u) {
    if ((u.scheme == 'https' && (u.port == 0 || u.port == 443)) ||
        (u.scheme == 'http' && (u.port == 0 || u.port == 80))) {
      return '';
    }
    return u.port.toString();
  }

  final samePort = normalizePort(url) == normalizePort(redirect);

  String normPath(String p) {
    // Dart Uri.path usually starts with / if not empty.
    var withLeading = p.startsWith('/') ? p : '/$p';
    // strip trailing slashes, keep root as "/"
    return withLeading.replaceAll(RegExp(r'/+$'), '') == ''
        ? '/'
        : withLeading.replaceAll(RegExp(r'/+$'), '');
  }

  final urlPath = normPath(url.path);
  final redirectPath = normPath(redirect.path);

  final pathMatches =
      urlPath == redirectPath || urlPath.startsWith('$redirectPath/');

  return sameProtocol && sameHost && samePort && pathMatches;
}

// PKCE Helpers

String genPkceCodeVerifier() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return _encodeForPkce(Uint8List.fromList(bytes));
}

String pkceCodeChallenge(String verifier, String method) {
  if (method == pkcePlain) {
    return verifier;
  }

  final bytes = utf8.encode(verifier);
  final digest = sha256.convert(bytes);
  return _encodeForPkce(Uint8List.fromList(digest.bytes));
}

String _encodeForPkce(Uint8List bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}

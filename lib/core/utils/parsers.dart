import 'dart:io';

import 'package:api_craft/core/models/cookie_jar_model.dart';
import 'package:api_craft/api_client/request/models/node_config_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ParserUtils {
  ParserUtils._();

  static List<List<String>> parseQuery(String? raw) {
    debugPrint('parsing query');
    final pathList = raw?.split('?') ?? [];
    if (pathList.length < 2) return [];
    final queryParams = pathList[1];
    if (queryParams.isEmpty) return [];
    return queryParams.split('&').map((e) {
      final parts = e.split('=');
      final key = Uri.decodeComponent(parts[0]);
      final value = parts.length > 1 ? Uri.decodeComponent(parts[1]) : '';
      return [key, value];
    }).toList();
  }

  static String buildUrl(String url, List<KeyValueItem> queryParams) {
    final uri = Uri.parse(url);
    final params = <String, List<String>>{};
    for (final element in queryParams) {
      if (element.isEnabled) {
        final key = Uri.encodeComponent(element.key);
        final value = Uri.encodeComponent(element.value);
        params.putIfAbsent(key, () => []).add(value);
      }
    }
    return uri.replace(queryParameters: params).toString();
  }

  static List<List<List<String>>> parseMultipleCookies(
    List<KeyValueItem> headers,
  ) {
    final cookies = headers
        .where((e) => e.key.toLowerCase() == 'cookie')
        .toList();
    return cookies.map((e) => parseCookies(e.value)).toList();
  }

  static List<List<String>> parseCookies(String raw) {
    debugPrint('parsing cookies');
    final cookieList = raw
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return cookieList.map((e) {
      final parts = e.split('=');
      final key = Uri.decodeComponent(parts[0]);
      final value = parts.length > 1
          ? Uri.decodeComponent(parts.sublist(1).join('='))
          : '';
      return [key, value];
    }).toList();
  }

  static List<CookieDef> parseSetCookies(List<String> cookies, Uri? uri) {
    final newCookies = <CookieDef>[];
    for (final cookie in cookies) {
      try {
        final c = Cookie.fromSetCookieValue(cookie);

        final isHostOnly = c.domain == null;
        final domain = c.domain ?? uri?.host.toLowerCase();
        final path = c.path ?? (uri != null ? _defaultPath(uri.path) : null);

        newCookies.add(
          CookieDef(
            key: c.name,
            value: c.value,
            domain: domain ?? '',
            path: path ?? '/',
            expires: c.expires,
            isSecure: c.secure,
            isHttpOnly: c.httpOnly,
            isHostOnly: isHostOnly,
          ),
        );
      } catch (e) {
        debugPrint("Failed to parse cookie: $cookie");
      }
    }
    return newCookies;
  }

  static String _defaultPath(String reqPath) {
    if (!reqPath.startsWith('/') || reqPath == '/') return '/';
    final i = reqPath.lastIndexOf('/');
    return i == 0 ? '/' : reqPath.substring(0, i);
  }
}

class HeaderUtils {
  static String? getValue(List<KeyValueItem> headers, String key) {
    final header = getKeyValue(headers, key);
    return header?.value;
  }

  static KeyValueItem? getKeyValue(List<KeyValueItem> headers, String key) {
    return headers.firstWhereOrNull(
      (e) => e.key.toLowerCase() == key.toLowerCase(),
    );
  }

  static List<KeyValueItem> get(List<KeyValueItem> headers, String key) {
    return headers
        .where((e) => e.key.toLowerCase() == key.toLowerCase())
        .toList();
  }

  static List<CookieDef> getSetCookies(List<KeyValueItem> headers, Uri? uri) {
    final setCookies = headers
        .where((e) => e.key.toLowerCase().trim() == 'set-cookie')
        .map((e) => e.value)
        .toList();
    return ParserUtils.parseSetCookies(setCookies, uri);
  }
}

class RawHeaderUtils {
  static String? getValue(List<List<String>> headers, String key) {
    final header = getKeyValue(headers, key);
    return header?[1];
  }

  static List<String>? getKeyValue(List<List<String>> headers, String key) {
    return headers.firstWhereOrNull(
      (e) => e[0].toLowerCase() == key.toLowerCase(),
    );
  }

  static List<List<String>> get(List<List<String>> headers, String key) {
    return headers
        .where((e) => e[0].toLowerCase() == key.toLowerCase())
        .toList();
  }

  static List<CookieDef> getSetCookies(List<List<String>> headers, Uri? uri) {
    final setCookies = headers
        .where((e) => e[0].toLowerCase() == 'set-cookie')
        .map((e) => e[1])
        .toList();
    return ParserUtils.parseSetCookies(setCookies, uri);
  }
}

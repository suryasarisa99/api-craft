import 'package:api_craft/core/models/cookie_jar_model.dart';

class CookieUtils {
  static bool domainMatches(Uri uri, CookieDef c) {
    if (c.domain.isEmpty) return false;
    // Host-only flag usually implies no leading dot and exact match,
    // but here we rely on the object's `isHostOnly` property or domain string.
    // If CookieDef has an explicit isHostOnly flag, use it.
    if (c.isHostOnly) {
      return uri.host == c.domain;
    }
    // Domain match:
    // The domain string should lower-case.
    // The request host should domain-match the cookie domain.
    // e.g. cookie domain "example.com" matches "example.com" and "www.example.com"
    final host = uri.host.toLowerCase();
    final domain = c.domain.toLowerCase();

    return host == domain || host.endsWith('.$domain');
  }

  static bool pathMatches(Uri uri, CookieDef c) {
    final cookiePath = c.path;
    final reqPath = uri.path.isEmpty ? '/' : uri.path;

    if (cookiePath == '/' || reqPath == cookiePath) return true;

    if (reqPath.startsWith(cookiePath)) {
      if (cookiePath.endsWith('/')) return true;
      if (reqPath[cookiePath.length] == '/') return true;
    }

    return false;
  }

  static List<CookieDef> getRelevantCookies(Uri uri, List<CookieDef> cookies) {
    return cookies.where((c) {
      if (!c.isEnabled) return false;
      if (!domainMatches(uri, c)) return false;
      if (!pathMatches(uri, c)) return false;
      if (c.isSecure && uri.scheme != 'https') return false;
      return true;
    }).toList();
  }

  static String generateCookieHeader(List<CookieDef> cookies) {
    return cookies.map((c) => '${c.key}=${c.value}').join('; ');
  }
}

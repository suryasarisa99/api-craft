class CookieDef {
  final String domain;
  final String path;
  final String key;
  final String value;
  final bool isSecure;
  final bool isHttpOnly;
  final bool isHostOnly;
  final DateTime? expires;
  final bool isEnabled;

  CookieDef({
    this.domain = '',
    this.path = '/',
    required this.key,
    required this.value,
    this.isSecure = false,
    this.isHttpOnly = false,
    this.isHostOnly = false,
    this.expires,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'domain': domain,
      'path': path,
      'key': key,
      'value': value,
      'isSecure': isSecure,
      'isHttpOnly': isHttpOnly,
      'isHostOnly': isHostOnly,
      'expires': expires?.toIso8601String(),
      'isEnabled': isEnabled,
    };
  }

  factory CookieDef.fromMap(Map<String, dynamic> map) {
    return CookieDef(
      domain: map['domain'] ?? '',
      path: map['path'] ?? '/',
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      isSecure: map['isSecure'] ?? false,
      isHttpOnly: map['isHttpOnly'] ?? false,
      isHostOnly: map['isHostOnly'] ?? false,
      expires: map['expires'] != null ? DateTime.parse(map['expires']) : null,
      isEnabled: map['isEnabled'] ?? true,
    );
  }

  CookieDef copyWith({
    String? domain,
    String? path,
    String? key,
    String? value,
    bool? isSecure,
    bool? isHttpOnly,
    bool? isHostOnly,
    DateTime? expires,
    bool? isEnabled,
  }) {
    return CookieDef(
      domain: domain ?? this.domain,
      path: path ?? this.path,
      key: key ?? this.key,
      value: value ?? this.value,
      isSecure: isSecure ?? this.isSecure,
      isHttpOnly: isHttpOnly ?? this.isHttpOnly,
      isHostOnly: isHostOnly ?? this.isHostOnly,
      expires: expires ?? this.expires,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class CookieJarModel {
  final String id;
  final String collectionId;
  final String name;
  final List<CookieDef> cookies;

  const CookieJarModel({
    required this.id,
    required this.collectionId,
    required this.name,
    this.cookies = const [],
  });

  CookieJarModel copyWith({
    String? id,
    String? collectionId,
    String? name,
    List<CookieDef>? cookies,
  }) {
    return CookieJarModel(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      name: name ?? this.name,
      cookies: cookies ?? this.cookies,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection_id': collectionId,
      'name': name,
      'cookies': cookies.map((e) => e.toMap()).toList(),
    };
  }

  factory CookieJarModel.fromMap(Map<String, dynamic> map) {
    var cookiesList = <CookieDef>[];
    if (map['cookies'] != null) {
      try {
        final List list = map['cookies'];
        cookiesList = list.map((e) => CookieDef.fromMap(e)).toList();
      } catch (e) {
        // ignore error
      }
    }
    return CookieJarModel(
      id: map['id'],
      collectionId: map['collection_id'],
      name: map['name'],
      cookies: cookiesList,
    );
  }
}

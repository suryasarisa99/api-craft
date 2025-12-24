Map<String, dynamic> rawHeadersToObject(List<List<String>> rawHeaders) {
  final Map<String, dynamic> headers = {};
  for (final header in rawHeaders) {
    if (header.length < 2) continue;

    final key = header[0].toLowerCase();
    final value = header[1];

    final existingValue = headers[key];

    if (existingValue is List) {
      existingValue.add(value);
    } else if (existingValue != null) {
      headers[key] = [existingValue, value];
    } else {
      headers[key] = value;
    }
  }
  return headers;
}

Map<String, dynamic> listHeadersToMap(List<List<String>> headers) {
  final Map<String, dynamic> headerMap = {};
  for (var header in headers) {
    final key = header[0];
    final value = header[1];
    // handle cookie
    if (key == 'cookie') {
      final existing = headerMap[key];
      if (existing != null) {
        headerMap[key] = '$existing; $value';
      } else {
        headerMap[key] = value;
      }
    }
    // handle repeatable headers
    else if (_isStrictNonRepeatable(key.toLowerCase())) {
      if (headerMap.containsKey(key)) {
        if (headerMap[key] is List) {
          headerMap[key].add(value);
        } else {
          headerMap[key] = [headerMap[key], value];
        }
      } else {
        headerMap[key] = value;
      }
    }
    // handle non-repeatable headers
    else {
      headerMap[key] = value;
    }
  }
  return headerMap;
}

class _HeaderEntry {
  String originalKey;
  List<String> values;

  _HeaderEntry(this.originalKey, this.values);
}

class HeaderUtils {
  // static List<List<String>> handleHeaders(
  //   List<List<String>> headers, {
  //   bool preserveCase = false,
  // }) {
  //   final List<List<String>> result = [];
  //   final Map<String, List<String>> headerMap = {};

  //   for (var header in headers) {
  //     final key = header[0].trim();
  //     final value = header[1].trim();
  //     final lowerKey = key.toLowerCase();
  //     if (_isStrictDuplicateHeader(lowerKey)) {
  //       if (headerMap.containsKey(lowerKey)) {
  //         headerMap[lowerKey]!.add(value);
  //       } else {
  //         headerMap[lowerKey] = [value];
  //       }
  //     } else if (_isCommaSeparatedHeader(lowerKey)) {
  //       if (headerMap.containsKey(lowerKey)) {
  //         headerMap[lowerKey]![0] = '${headerMap[lowerKey]![0]}, $value';
  //       } else {
  //         headerMap[lowerKey] = [value];
  //       }
  //     } else if (_isStrictNonRepeatable(lowerKey)) {
  //       // non-repeatable headers, overwrite existing
  //       headerMap[lowerKey] = [value];
  //     } else {
  //       /// later provide a option to allow user to choose
  //       /// for now, we just allow duplicate
  //       if (headerMap.containsKey(lowerKey)) {
  //         headerMap[lowerKey]!.add(value);
  //       } else {
  //         headerMap[lowerKey] = [value];
  //       }
  //     }
  //   }

  //   headerMap.forEach((key, values) {
  //     for (var value in values) {
  //       result.add([key, value]);
  //     }
  //   });

  //   return result;
  // }

  // TODO: resolve headers key variables first and then merge headers, later resolve header values.
  static List<List<String>> handleHeaders(
    List<List<String>> headers, {
    bool preserveCase = true,
  }) {
    final Map<String, _HeaderEntry> headerMap = {};

    for (final header in headers) {
      final key = header[0].trim();
      final value = header[1].trim();
      final lowerKey = key.toLowerCase();

      headerMap.putIfAbsent(lowerKey, () => _HeaderEntry(key, []));

      final entry = headerMap[lowerKey]!;

      // update casing only if preserveCase == false
      if (!preserveCase) {
        entry.originalKey = lowerKey;
      }

      if (_isStrictDuplicateHeader(lowerKey)) {
        entry.values.add(value);
      } else if (_isCommaSeparatedHeader(lowerKey)) {
        if (entry.values.isEmpty) {
          entry.values.add(value);
        } else {
          entry.values[0] = '${entry.values[0]}, $value';
        }
      } else if (_isStrictNonRepeatable(lowerKey)) {
        entry.values
          ..clear()
          ..add(value);
      } else {
        entry.values.add(value);
      }
    }

    final result = <List<String>>[];
    for (final entry in headerMap.values) {
      for (final value in entry.values) {
        result.add([entry.originalKey, value]);
      }
    }

    return result;
  }
}

// cookie can be repeated,to support old requests,user needs explicitly seperate by `;`
const kNonRepeatedHeaders = [
  'host',
  'content-length',
  'content-type',
  'user-agent',
  // 'cookie',
  ':method',
  ':path',
  ':scheme',
  ':authority',
];
// duplicate headers (not comma seperated)
// the headers
const kStrictDuplicateHeaders = [
  "authorization",
  "proxy-authorization",
  "set-cookie",
  "www-authenticate",
  "proxy-authenticate",
  "link",
  "date",
  "expires",
  "last-modified",
  "if-modified-since",
  "warning",
  "cookie", // some old requests use multiple cookie headers
  "etag",
  "content-location",
  "retry-after",
  "content-disposition",
];
const kCommaSeparatedHeaders = [
  'accept',
  'accept-language',
  'accept-encoding',
  'cache-control',
  'pragma',
  'vary',
  'via',
  'connection',
  'upgrade',
  'trailer',
  'te',
  'transfer-encoding',
  'access-control-allow-headers',
  'access-control-allow-methods',
  'access-control-expose-headers',
  'x-forwarded-for',
];
bool _isStrictNonRepeatable(String key) {
  return kNonRepeatedHeaders.contains(key.toLowerCase());
}

bool _isStrictDuplicateHeader(String key) {
  return kStrictDuplicateHeaders.contains(key.toLowerCase());
}

bool _isCommaSeparatedHeader(String key) {
  return kCommaSeparatedHeaders.contains(key.toLowerCase());
}

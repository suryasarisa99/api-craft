import 'dart:io';
import 'package:api_craft/core/models/models.dart';

final client = HttpClient()
  ..connectionTimeout = const Duration(seconds: 5)
  ..idleTimeout = const Duration(seconds: 5)
  ..findProxy = (Uri uri) {
    // Example: use proxy for all requests
    // return "DIRECT";
    // return "PROXY 127.0.0.1:8080";
    return "PROXY 127.0.0.1:8080; DIRECT";
  };

Future<HttpClientResponse> httpRequest({
  required String method,
  required Uri url,
  List<List<String>>? headers,
  dynamic body,
}) async {
  final request = await client.openUrl(method.toUpperCase(), url);

  // add headers (supports duplicate values)
  if (headers != null) {
    for (var header in headers) {
      request.headers.add(header[0], header[1]);
    }
  }

  // write body if provided
  if (body != null) {
    if (body is String) {
      request.write(body);
    } else if (body is List<int>) {
      request.add(body);
    } else {
      throw ArgumentError('Body must be String or List<int>');
    }
  }

  return await request.close(); // returns HttpClientResponse
}

List<KeyValueItem> cleanHeaders(List<KeyValueItem> headers) {
  return [
    for (var h in headers)
      if (h.isEnabled && h.key.trim().isNotEmpty)
        KeyValueItem(
          key: h.key.trim(),
          value: h.value.trim(),
          isEnabled: h.isEnabled,
        ),
  ];
}

List<List<String>> headersHandle(
  List<KeyValueItem> headers,
  List<KeyValueItem> inherited,
) {
  final merged = [...cleanHeaders(inherited), ...cleanHeaders(headers)];
  return [
    for (var h in merged) [h.key, h.value],
  ];
}

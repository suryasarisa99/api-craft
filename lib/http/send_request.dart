import 'package:api_craft/http/header_utils.dart';
import 'package:api_craft/http/raw_req.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter/cupertino.dart';

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

void run(ResolveConfig config) async {
  final node = config.node as RequestNode;
  final uri = Uri.parse(node.url);
  final headers = headersHandle(
    node.config.headers,
    config.inheritedHeaders ?? [],
  );
  // encode + filter query parameters
  final queryParams = [
    for (var qp in node.config.queryParameters)
      if (qp.isEnabled)
        "${Uri.encodeQueryComponent(qp.key)}=${Uri.encodeQueryComponent(qp.value)}",
  ].join('&');
  // append query params to uri
  final uriWithQuery = queryParams.isNotEmpty
      ? uri.replace(
          query: uri.query.isNotEmpty
              ? "${uri.query}&$queryParams"
              : queryParams,
        )
      : uri;
  debugPrint("uri with query: $uriWithQuery");
  debugPrint("=== RUN REQUEST ======================");
  debugPrint("Running request: ${node.method} $uri");
  debugPrint("Headers: ${headers.length}");
  // httpEngine
  //     .send(
  //       method: node.method,
  //       url: node.url,
  //       headers: listHeadersToMap(headers),
  //     )
  //     .then((response) async {
  //       debugPrint('Response status: ${response.statusCode}');
  //       final responseBody = await response.data;
  //       debugPrint('Response body: $responseBody');
  //     })
  //     .catchError((error) {
  //       debugPrint('Request error: $error');
  //     });
  const bodies = [
    """{
  "username":"surya",
  "password":"123"
}""",
  ];
  // calculate res time
  final responseStart = DateTime.now();
  final response = await sendRawHttp(
    method: node.method,
    url: uriWithQuery,
    // url: uri,
    headers: HeaderUtils.handleHeaders(headers),
    body: bodies[0],
    useProxy: true,
    // url: uriWithQuery.toString(),
    // headers: listHeadersToMap(headers),
  );
  final responseEnd = DateTime.now();
  final responseDuration = responseEnd.difference(responseStart);
  debugPrint('Response status: $response');
  debugPrint('Response time: ${responseDuration.inMilliseconds} ms');

  // debugPrint('Response status: ${response.statusCode}');
  // final responseBody = await response.transform(utf8.decoder).join();
  // debugPrint('Response body: $responseBody');
}

import 'package:api_craft/http/header_utils.dart';
import 'package:api_craft/http/raw/raw_http_req.dart';
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

// we need to handle variable values,itself uses another variables
Map<String, VariableValue> resolveVariableValues(
  Map<String, VariableValue> vars,
  int depth,
) {
  if (depth <= 0) return vars; // prevent infinite loop

  final resolved = <String, VariableValue>{};

  for (var entry in vars.entries) {
    final key = entry.key;
    final value = entry.value.value;

    if (value is String) {
      final resolvedValue = resolveVariables(
        value,
        vars,
      ); // recursive resolution
      resolved[key] = VariableValue(entry.value.sourceId, resolvedValue);
    } else {
      resolved[key] = entry.value; // non-string values remain unchanged
    }
  }

  return resolveVariableValues(resolved, depth - 1);
}

final _variableRegExp = RegExp(r'{{\s*([a-zA-Z0-9_-]+)\s*}}');
// final _variableRegExp = RegExp(r'{{\s*([^{}\s]+)\s*}}');
String resolveVariables(String text, Map<String, VariableValue> values) {
  // Match all {{variable}} patterns
  debugPrint("Resolving variables in text: $text");
  return text.replaceAllMapped(_variableRegExp, (match) {
    final key = match.group(1);
    if (key != null && values.containsKey(key)) {
      debugPrint("Resolving variable: $key");
      return values[key]!.value; // Replace with value
    }
    return match.group(0)!; // leave as is if no value found
  });
}

Future<RawHttpResponse> run(ResolveConfig config) async {
  final node = config.node as RequestNode;
  late List<List<String>> headers = headersHandle(
    node.config.headers,
    config.inheritedHeaders ?? [],
  );

  /// handle variable injection

  final variables = resolveVariableValues(config.allVariables ?? {}, 99);
  final resolvedUrl = resolveVariables(node.url, variables);
  final uri = Uri.parse(resolvedUrl);
  // for headers
  headers = [
    for (var header in headers)
      [
        resolveVariables(header[0], variables),
        resolveVariables(header[1], variables),
      ],
  ];
  // for query parameters
  final queryParameters = [
    for (var qp in node.config.queryParameters)
      KeyValueItem(
        key: resolveVariables(qp.key, config.allVariables ?? {}),
        value: resolveVariables(qp.value, config.allVariables ?? {}),
        isEnabled: qp.isEnabled,
      ),
  ];

  /// Handle Headers, Params Merging
  headers = HeaderUtils.handleHeaders(headers);
  // encode + filter query parameters
  final queryParams = [
    for (var qp in queryParameters)
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
    headers: headers,
    body: bodies[0],
    useProxy: false,
    requestId: node.id,
  );
  final responseEnd = DateTime.now();
  final responseDuration = responseEnd.difference(responseStart);
  debugPrint('Response status: ${response}');
  debugPrint('Response time: ${responseDuration.inMilliseconds} ms');
  return response;
}
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
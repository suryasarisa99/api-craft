import 'dart:convert';

import 'package:api_craft/http/raw/raw_http_req.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// this actually does not store any state
// but made this provider because it uses RequestResolver which requires Ref,
//but we need to use reqExecutor in ui it is WidgetRef, so we can't pass WidgetRef to RequestResolver directly
final requestExecutorProvider = Provider<RequestExecutor>((ref) {
  return RequestExecutor(ref);
});

class RequestExecutor {
  final Ref ref;
  RequestExecutor(this.ref);

  Future<RawHttpResponse> runById(String requestId) async {
    final resolver = RequestResolver(ref);
    final ctx = await resolver.resolveForExecution(requestId);
    debugPrint('Executing request to URL: ${ctx.uri}');

    final response = await sendRawHttp(
      method: ctx.request.method,
      url: ctx.uri,
      headers: ctx.headers,
      // body: ctx.request.config.body,
      body: _bodies[0],
      useProxy: true,
      requestId: ctx.request.id,
    );
    final body = jsonDecode(response.body);
    final token = body['token'].toString();
    debugPrint(
      'Response status: ${response.statusCode}: ${response.durationMs} ms, ${token.substring(token.length - 8)}',
    );

    return response;
  }
}

/// for testing purposes
const _bodies = [
  """{
  "username":"surya",
  "password":"123"
}""",
];

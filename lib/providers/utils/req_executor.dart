import 'dart:convert';

import 'package:api_craft/http/raw/raw_http_req.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// this actually does not store any state
// but made this provider because it uses RequestResolver which requires Ref,
//but we need to use reqExecutor in ui it is WidgetRef, so we can't pass WidgetRef to RequestResolver directly
final httpRequestProvider = Provider<HttpRequestContext>((ref) {
  return HttpRequestContext(ref);
});

class HttpRequestContext {
  final Ref ref;
  HttpRequestContext(this.ref);

  Future<RawHttpResponse> runById(String requestId) async {
    final resolver = RequestResolver(ref);
    final req = await resolver.resolveForExecution(requestId);
    debugPrint('Executing request to URL: ${req.uri}');

    final response = await sendRawHttp(
      method: req.request.method,
      url: req.uri,
      headers: req.headers,
      // body: ctx.request.config.body,
      body: _bodies[0],
      useProxy: true,
      requestId: req.request.id,
    );
    final body = jsonDecode(response.body);
    final token = body['token'].toString();
    debugPrint(
      'Response status: ${response.statusCode}: ${response.durationMs} ms, ${token.substring(token.length - 8)}',
    );

    return response;
  }

  Future<RawHttpResponse?> getResById(String requestId) async {
    final repo = ref.read(repositoryProvider);
    final responses = await repo.getHistory(requestId, limit: 1);
    if (responses.isNotEmpty) {
      return responses.first;
    }
    return null;
  }
}

/// for testing purposes
const _bodies = [
  """{
  "username":"surya",
  "password":"123"
}""",
];

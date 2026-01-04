import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:nanoid/nanoid.dart';

import 'package:api_craft/core/network/raw/raw_http_req.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/js_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HttpService {
  Future<RawHttpResponse> run(
    Ref ref,
    String requestId, {
    required BuildContext context,
  }) async {
    final resolver = ref.read(requestResolverProvider);
    final isActiveReq = ref.read(activeReqIdProvider) == requestId;
    //NOTE: use composer only when the request is active,otherwise it will throw error
    ReqComposeNotifier? composer;
    if (isActiveReq) {
      composer = ref.read(reqComposeProvider(requestId).notifier);
    }

    try {
      final req = await resolver.resolveForExecution(
        requestId,
        context: context,
      );
      debugPrint('Executing request to URL: ${req.uri}');

      composer?.startSending();
      final response = await sendRawHttp(
        method: req.request.method,
        url: req.uri,
        headers: req.headers,
        body: req.body is Map ? jsonEncode(req.body) : req.body,
        useProxy: false,
        requestId: req.request.id,
        maxRedirects: 50,
      );
      debugPrint(
        'Response status: ${response.statusCode}: ${response.durationMs} ms',
      );

      // store into history
      if (isActiveReq) {
        composer?.addHistoryEntry(response);
      } else {
        ref.read(dataRepositoryProvider).addHistoryEntry(response);
      }

      // Extract & Save Cookies
      final cookieJarId = ref.read(environmentProvider).selectedCookieJarId;
      if (cookieJarId != null) {
        final newCookies = <CookieDef>[];
        for (final h in response.headers) {
          if (h[0].toLowerCase() == 'set-cookie') {
            try {
              final c = Cookie.fromSetCookieValue(h[1]);

              final isHostOnly = c.domain == null;
              final domain = (c.domain ?? req.uri.host).toLowerCase();
              final path = c.path ?? _defaultPath(req.uri.path);

              newCookies.add(
                CookieDef(
                  key: c.name,
                  value: c.value,
                  domain: domain,
                  path: path,
                  expires: c.expires,
                  isSecure: c.secure,
                  isHttpOnly: c.httpOnly,
                  isHostOnly: isHostOnly,
                ),
              );
            } catch (e) {
              debugPrint("Failed to parse cookie: ${h[1]}");
            }
          }
        }
        if (newCookies.isNotEmpty) {
          ref
              .read(environmentProvider.notifier)
              .saveCookiesToJar(cookieJarId, newCookies);
        }
      }

      // 4. Run Scripts
      final scripts = req.request.reqConfig.scripts;
      if (scripts != null && scripts.isNotEmpty) {
        debugPrint("Running post-response script...");
        await ref
            .read(jsEngineProvider)
            .executeScript(scripts, response: response);
      }

      composer?.finishSending();
      return response;
    } catch (e, stack) {
      debugPrint("Error sending request: $e\n$stack");

      final errorResponse = RawHttpResponse(
        id: nanoid(),
        requestId: requestId,
        statusCode: 0,
        statusMessage: 'Error',
        protocolVersion: '',
        headers: [],
        bodyBytes: Uint8List(0),
        body: e.toString(),
        executeAt: DateTime.now(),
        durationMs: 0,
        errorMessage: e.toString(),
      );

      if (isActiveReq) {
        composer?.addHistoryEntry(errorResponse);
      } else {
        ref.read(dataRepositoryProvider).addHistoryEntry(errorResponse);
      }

      composer?.setSendError(e.toString());
      rethrow;
    }
  }

  Future<RawHttpResponse?> getRes(Ref ref, String requestId) async {
    final repo = ref.read(dataRepositoryProvider);
    final responses = await repo.getHistory(requestId, limit: 1);
    if (responses.isNotEmpty) {
      return responses.first;
    }
    return null;
  }

  String _defaultPath(String reqPath) {
    if (!reqPath.startsWith('/') || reqPath == '/') return '/';
    final i = reqPath.lastIndexOf('/');
    return i == 0 ? '/' : reqPath.substring(0, i);
  }
}

/// for testing purposes

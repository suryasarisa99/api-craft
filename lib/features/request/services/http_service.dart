import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:nanoid/nanoid.dart';

import 'package:api_craft/core/network/raw/raw_http_req.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/js_engine.dart';
import 'package:api_craft/core/services/script_execution_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:api_craft/core/services/assertion_service.dart';

class HttpService {
  Future<RawHttpResponse> run(
    Ref ref,
    String requestId, {
    required BuildContext context,
  }) async {
    final resolver = RequestResolver(ref);
    final isActiveReq = ref.read(activeReqIdProvider) == requestId;
    //NOTE: use composer only when the request is active,otherwise it will throw error
    ReqComposeNotifier? composer;
    if (isActiveReq) {
      composer = ref.read(reqComposeProvider(requestId).notifier);
    }

    try {
      // 1. Run Pre-Request Script
      // We run pre-scripts BEFORE resolving the request, allowing them to modify the request node/config.
      final preScripts = ref
          .read(scriptExecutionProvider)
          .getScriptsToRun(requestId, ScriptType.preRequest);

      if (preScripts.isNotEmpty) {
        debugPrint("Running ${preScripts.length} pre-request scripts...");
        for (final script in preScripts) {
          await ref
              .read(jsEngineProvider)
              .executeScript(requestId, script, context: context);
        }
      }

      // 2. Resolve Request (Now reflects changes from pre-scripts)
      final req = await resolver.resolveForExecution(
        requestId,
        context: context,
      );
      debugPrint('Executing request to URL: ${req.uri}');

      composer?.startSending();

      RawHttpResponse response = await sendRawHttp(
        method: req.request.method,
        url: req.uri,
        headers: req.headers,
        body: req.body is Map ? jsonEncode(req.body) : req.body,
        useProxy: true,
        requestId: req.request.id,
        maxRedirects: 50,
      );
      debugPrint(
        'Response status: ${response.statusCode}: ${response.durationMs} ms',
      );

      // Extract & Save Cookies (Before scripts in case scripts rely on them? Or after?)
      // Scripts might want to access cookies.
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

      // 4. Run Scripts & Tests
      List<TestResult> allTestResults = [];

      final postScripts = ref
          .read(scriptExecutionProvider)
          .getScriptsToRun(requestId, ScriptType.postRequest);
      if (postScripts.isNotEmpty) {
        debugPrint("Running ${postScripts.length} post-request scripts...");
        for (final script in postScripts) {
          final results = await ref
              .read(jsEngineProvider)
              .executeScript(
                requestId,
                script,
                response: response,
                context: context,
              );
          allTestResults.addAll(results);
        }
      }

      final testScripts = ref
          .read(scriptExecutionProvider)
          .getScriptsToRun(requestId, ScriptType.test);
      if (testScripts.isNotEmpty) {
        debugPrint("Running ${testScripts.length} test scripts...");
        for (final script in testScripts) {
          final results = await ref
              .read(jsEngineProvider)
              .executeScript(
                requestId,
                script,
                response: response,
                context: context,
              );
          allTestResults.addAll(results);
        }
      }

      // 5. Evaluate Assertions
      List<TestResult> assertionResults = [];
      final node = ref.read(fileTreeProvider).nodeMap[requestId];
      if (node is RequestNode && node.reqConfig.assertions.isNotEmpty) {
        assertionResults = AssertionService.evaluate(
          node.reqConfig.assertions,
          response,
        );
      }

      // 6. Update Response with Tests & Assertions
      response = response.copyWith(
        testResults: allTestResults,
        assertionResults: assertionResults,
      );

      // 7. Store into History
      if (isActiveReq) {
        composer?.addHistoryEntry(response);
      } else {
        ref.read(dataRepositoryProvider).addHistoryEntry(response);
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

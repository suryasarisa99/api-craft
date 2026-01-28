import 'dart:typed_data';
import 'dart:convert';
import 'package:api_craft/core/utils/parsers.dart';
import 'package:nanoid/nanoid.dart';

import 'package:api_craft/core/network/raw/raw_http_req.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/js_engine.dart';
import 'package:api_craft/core/services/script_execution_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/api_client/request/providers/request_loading_provider.dart';

import 'package:api_craft/core/services/assertion_service.dart';

class HttpService {
  Future<ResponseHistory> run(
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

      if (!context.mounted) throw Exception('Context unmounted');

      // 2. Resolve Request (Now reflects changes from pre-scripts)
      final req = await resolver.resolveForExecution(
        requestId,
        context: context,
      );
      debugPrint('Executing request to URL: ${req.uri}');

      ref.read(requestLoadingProvider(requestId).notifier).startSending();

      // IMPL: Get Cookies from Jar
      final cookieJarId = ref.read(environmentProvider).selectedCookieJarId;
      List<CookieDef> initialCookies = [];
      if (cookieJarId != null) {
        final jar = ref.read(environmentProvider).selectedCookieJar;
        if (jar != null) {
          initialCookies = jar.cookies;
        }
      }

      ResponseHistory response = await sendRawHttp(
        method: req.request.method,
        url: req.uri,
        headers: req.headers,
        body: req.body is Map ? jsonEncode(req.body) : req.body,
        // Proxy Settings
        useProxy: req.proxy.isEnabled,
        proxyHost: req.proxy.host ?? '127.0.0.1',
        proxyPort: int.tryParse(req.proxy.port ?? '') ?? 8080,
        proxyUsername: req.proxy.username,
        proxyPassword: req.proxy.password,
        proxyProtocol: req.proxy.protocol,
        // Request Settings
        maxRedirects: req.settings.maxRedirects ?? 5,
        followRedirects:
            req.settings.followRedirects ??
            true, // This param might not exist in sendRawHttp yet
        requestId: req.request.id,
        cookiesJar: initialCookies,
      );
      debugPrint(
        'Response status: ${response.statusCode}: ${response.durationMs} ms',
      );

      // Extract & Save Cookies (Before scripts)
      if (cookieJarId != null) {
        // 1. From Redirects
        for (final step in response.redirects) {
          try {
            final stepUri = Uri.parse(step.url);
            final stepCookies = RawHeaderUtils.getSetCookies(
              step.resHeaders,
              stepUri,
            );
            if (stepCookies.isNotEmpty) {
              ref
                  .read(environmentProvider.notifier)
                  .saveCookiesToJar(cookieJarId, stepCookies);
            }
          } catch (e) {
            debugPrint("Error saving redirect cookies: $e");
          }
        }

        // 2. From Final Response
        if (response.resCookies.isNotEmpty) {
          ref
              .read(environmentProvider.notifier)
              .saveCookiesToJar(cookieJarId, response.resCookies);
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
          if (!context.mounted) throw Exception('Context unmounted');
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
          if (!context.mounted) throw Exception('Context unmounted');
        }
      }

      // 5. Evaluate Assertions
      List<TestResult> assertionResults = [];
      final nodeMap = ref.read(fileTreeProvider).nodeMap;
      final node = nodeMap[requestId];

      if (node != null) {
        // Collect all definitions (Parents -> Child)
        final allAssertions = <AssertionDefinition>[];

        // Helper to collect parent assertions recursively
        // We traverse UP from the node to the root
        var current = node;
        final lineage = <Node>[];

        // 1. Build lineage (Leaf -> Root)
        while (current.parentId != null) {
          final parent = nodeMap[current.parentId];
          if (parent != null) {
            lineage.add(parent);
            current = parent;
          } else {
            break; // Broken chain
          }
        }

        // 2. Add Parent Assertions (Root -> Parent) (Reverse lineage)
        for (final ancestor in lineage.reversed) {
          if (ancestor is FolderNode) {
            allAssertions.addAll(ancestor.config.assertions);
          }
        }

        // 3. Add Node Assertions
        if (node is RequestNode) {
          allAssertions.addAll(node.reqConfig.assertions);
        } else if (node is FolderNode) {
          // Should not run request for folder directly usually, but if so:
          allAssertions.addAll(node.config.assertions);
        }

        if (allAssertions.isNotEmpty) {
          debugPrint(
            "Evaluating ${allAssertions.length} hierarchical assertions...",
          );
          assertionResults = AssertionService.evaluate(allAssertions, response);
        }
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

      ref.read(requestLoadingProvider(requestId).notifier).finishSending();
      return response;
    } catch (e, stack) {
      debugPrint("catch: Error sending request: $e\n$stack");

      final errorResponse = ResponseHistory(
        id: nanoid(),
        requestId: requestId,
        statusCode: 0,
        statusMessage: 'Error',
        protocolVersion: '',
        headers: [],
        bodyBytes: Uint8List(0),
        executeAt: DateTime.now(),
        durationMs: 0,
        errorMessage: e.toString(),
      );

      if (isActiveReq) {
        composer?.addHistoryEntry(errorResponse);
      } else {
        ref.read(dataRepositoryProvider).addHistoryEntry(errorResponse);
      }

      ref
          .read(requestLoadingProvider(requestId).notifier)
          .setError(e.toString());
      rethrow;
    }
  }

  Future<ResponseHistory?> getRes(Ref ref, String requestId) async {
    final repo = ref.read(dataRepositoryProvider);
    final responses = await repo.getHistory(requestId, limit: 1);
    if (responses.isNotEmpty) {
      return responses.first;
    }
    return null;
  }
}

/// for testing purposes

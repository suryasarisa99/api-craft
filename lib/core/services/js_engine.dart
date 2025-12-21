import 'dart:convert';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/env_service.dart';
import 'package:api_craft/core/services/req_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jsEngineProvider = Provider((ref) => JsEngineService(ref));

class JsEngineService {
  final Ref ref;
  JsEngineService(this.ref);

  Future<void> executeScript(String script, {RawHttpResponse? response}) async {
    final JavascriptRuntime jsRuntime = getJavascriptRuntime();

    try {
      // 1. Inject API bridge
      jsRuntime.onMessage('setVariable', (args) {
        final String key = args['key'];
        final dynamic value = args['value'];
        debugPrint('JS: Setting variable $key = $value');
        EnvService.setVariable(ref, key: key, value: value?.toString() ?? '');
      });
      jsRuntime.onMessage('getUrl', (_) {
        final id = ref.read(activeReqIdProvider);
        final String url = ReqService.getUrl(ref, id ?? '') ?? '';
        debugPrint('JS: Getting URL $url');
        return url;
      });
      jsRuntime.onMessage('getMethod', (_) {
        final id = ref.read(activeReqIdProvider);
        final String method = ReqService.getMethod(ref, id ?? '') ?? '';
        debugPrint('JS: Getting Method $method');
        return method;
      });
      jsRuntime.onMessage('setUrl', (args) {
        final String url = args['url'];
        debugPrint('JS: Setting URL $url');
        ReqService.setUrl(ref, url);
      });

      String responseJson = "null";
      if (response != null) {
        final Map<String, dynamic> resMap = {
          'statusCode': response.statusCode,
          'body': response.body,
          'headers': response.headers,
        };
        responseJson = jsonEncode(resMap);
      }

      final String bridge =
          """
        var api = {
          response: $responseJson,
          setVariable: function(key, value) {
            // macOS/JavascriptCore likely uses 'sendMessage'
            if (typeof sendMessage !== 'undefined') {
              sendMessage('setVariable', JSON.stringify({ key: key, value: value }));
            } else if (typeof SendMessage !== 'undefined') {
               SendMessage('setVariable', JSON.stringify({ key: key, value: value }));
            } else {
               console.log("No sendMessage found");
            }
          }
        };
        var req={
         getUrl: function() {
           return sendMessage('getUrl');
         },
         getMethod: function() {
           return sendMessage('getMethod');
         },
         setUrl: function(url){
          var payload = JSON.stringify({ url: url });
          return sendMessage('setUrl', payload);
         }
        };
      """;

      // 2. Execute
      // We use evaluate instead of evaluateAsync for better stability on some macOS environments
      final result = jsRuntime.evaluate(bridge + "\n" + script);
      if (result.isError) {
        debugPrint('JS Script Error: ${result.stringResult}');
      }
    } catch (e) {
      debugPrint('JS Runtime Error: $e');
    } finally {
      // Small delay before disposal to ensure background callbacks are processed
      Future.delayed(const Duration(milliseconds: 500), () {
        jsRuntime.dispose();
      });
    }
  }
}

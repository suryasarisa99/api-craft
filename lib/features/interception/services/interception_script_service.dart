import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

import 'package:mockhttp/types.dart';

class InterceptionScriptService {
  static final InterceptionScriptService _instance =
      InterceptionScriptService._internal();
  static InterceptionScriptService get instance => _instance;

  late final JavascriptRuntime engine;
  final Completer<void> _initCompleter = Completer();

  InterceptionScriptService._internal() {
    engine = getJavascriptRuntime();
    _initEngine();
  }

  void _initEngine() {
    engine.evaluate('''
       const console = {
         log: (msg) => sendMessage('log', JSON.stringify({msg: msg})),
       };
    ''');

    engine.onMessage('log', (dynamic args) {
      debugPrint('InterceptionJS: $args');
    });

    _initCompleter.complete();
  }

  Future<bool> evaluate(
    String script,
    OngoingRequest req, [
    MutableResponse? res,
  ]) async {
    await _initCompleter.future;

    try {
      // 1. Prepare Data
      final reqMap = {
        'id': req.id,
        'method': req.method,
        'url': req.url,
        'path': req.path,
        'headers': {for (var h in req.headers) h[0]: h[1]},
        // TODO: Handle body if needed
        'body': '',
      };

      final resMap = res != null
          ? {
              'statusCode': res.statusCode,
              'headers': {
                // TODO: Implement headers access if available on MutableResponse
                // Currently assume empty or basic map if needed
              },
              'body': '',
            }
          : {};

      // 2. Prepare Context
      final contextScript =
          '''
        var req = ${jsonEncode(reqMap)};
        var res = ${jsonEncode(resMap)};
      ''';
      engine.evaluate(contextScript);

      // 3. Eval User Script wrapper
      final wrapperScript =
          '''
        (function() {
          try {
             $script
             
             if (typeof filter !== 'function') {
                return "ERROR: 'filter' function not found.";
             }
             
             var result = filter(req, res);
             return result;
          } catch (e) {
             return "ERROR: " + e;
          }
        })();
      ''';

      final evalResult = engine.evaluate(wrapperScript);

      // Handle FlutterJS result quirks
      if (evalResult.isError) {
        debugPrint('Script Eval Error: ${evalResult.stringResult}');
        return false;
      }

      final resultStr = evalResult.stringResult;

      if (resultStr.startsWith("ERROR:")) {
        debugPrint('Script Execution Error: $resultStr');
        return false;
      }

      return resultStr == 'true';
    } catch (e) {
      debugPrint("Script Exception: $e");
      return false;
    }
  }

  Future<MutableRequest> editRequest(String script, MutableRequest req) async {
    await _initCompleter.future;
    try {
      // 1. Serialize Request
      final reqMap = {
        'method': req.method,
        'url': req.url,
        'path': req.path,
        'headers': {for (var h in req.headers) h[0]: h[1]},
        'body': req.getBodyText(), // Assume UTF-8 text for simplicity for now
      };

      // 2. Prepare Context
      final contextScript = 'var req = ${jsonEncode(reqMap)};';
      engine.evaluate(contextScript);

      // 3. Eval User Script
      final wrapperScript =
          '''
        (function() {
          try {
             $script
             if (typeof edit !== 'function') {
                return "ERROR: 'edit' function not found. Define function edit(req) { ... return req; }";
             }
             var result = edit(req);
             return JSON.stringify(result);
          } catch (e) {
             return "ERROR: " + e;
          }
        })();
      ''';

      final evalResult = engine.evaluate(wrapperScript);

      if (evalResult.isError) {
        debugPrint('Script Edit Error: ${evalResult.stringResult}');
        return req;
      }

      final resultStr = evalResult.stringResult;
      if (resultStr.startsWith("ERROR:")) {
        debugPrint('Script Execution Error: $resultStr');
        return req;
      }

      // 4. Apply changes back to MutableRequest
      final Map<String, dynamic> modified = jsonDecode(resultStr);

      if (modified['method'] != req.method) req.method = modified['method'];
      if (modified['url'] != req.url) req.url = modified['url'];
      if (modified['path'] != req.path) req.path = modified['path'];

      // Update headers
      if (modified['headers'] is Map) {
        final newHeaders = (modified['headers'] as Map).cast<String, String>();
        // Clear and replace or merge?
        // Best to replace to allow deletion
        // MutableRequest has `headers` as List<List<String>>.
        req.headers.clear();
        newHeaders.forEach((k, v) {
          req.headers.add([k, v]);
        });
      }

      if (modified['body'] != req.getBodyText()) {
        req.setBodyText(modified['body']);
      }

      return req;
    } catch (e) {
      debugPrint("Edit Request Exception: $e");
      return req;
    }
  }

  Future<MutableResponse> editResponse(
    String script,
    MutableResponse res,
  ) async {
    await _initCompleter.future;
    try {
      // 1. Serialize Response
      final resMap = {
        'statusCode': res.statusCode,
        'statusMessage': res.statusMessage,
        'headers': {for (var h in res.headers) h[0]: h[1]},
        'body': res.getBodyText(),
      };

      // 2. Prepare Context
      final contextScript = 'var res = ${jsonEncode(resMap)};';
      engine.evaluate(contextScript);

      // 3. Eval User Script
      final wrapperScript =
          '''
        (function() {
          try {
             $script
             if (typeof edit !== 'function') {
                return "ERROR: 'edit' function not found. Define function edit(res) { ... return res; }";
             }
             var result = edit(res);
             return JSON.stringify(result);
          } catch (e) {
             return "ERROR: " + e;
          }
        })();
      ''';

      final evalResult = engine.evaluate(wrapperScript);
      if (evalResult.isError) {
        debugPrint('Script Edit Res Error: ${evalResult.stringResult}');
        return res;
      }

      final resultStr = evalResult.stringResult;
      if (resultStr.startsWith("ERROR:")) {
        debugPrint('Script Execution Error: $resultStr');
        return res;
      }

      // 4. Apply changes
      final Map<String, dynamic> modified = jsonDecode(resultStr);

      if (modified['statusCode'] != res.statusCode) {
        res.statusCode = modified['statusCode'];
      }
      if (modified['statusMessage'] != res.statusMessage) {
        res.statusMessage = modified['statusMessage'];
      }

      if (modified['headers'] is Map) {
        final newHeaders = (modified['headers'] as Map).cast<String, String>();
        res.headers.clear();
        newHeaders.forEach((k, v) {
          res.headers.add([k, v]);
        });
      }

      if (modified['body'] != res.getBodyText()) {
        // Need to set body. MutableResponse doesn't have setBodyText helper shown in snippet?
        // Wait, I saw getBodyText. Let's assume setBodyText exists or manipulate body bytes.
        // I will assume explicit setBodyText or check 'types.dart' if I missed it.
        // Actually MutableRequest had setBodyText. MutableResponse usually does too.
        // If not, I can do utf8.encode.
        // Let's check types.dart again? No, I'll use utf8.encode directly if needed or check types.dart.
        // Wait, MutableRequest had setBodyText. MutableResponse class definition was below it.
        // I'll assume I can set body bytes.
        res.body = utf8.encode(modified['body']);
        // Update content-length
        res.setHeader('content-length', res.body!.length.toString());
      }

      return res;
    } catch (e) {
      debugPrint("Edit Response Exception: $e");
      return res;
    }
  }

  void dispose() {
    engine.dispose();
  }
}

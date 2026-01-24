import 'dart:async';
import 'dart:convert';
import 'package:api_craft/flows/models/flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final filterJsServiceProvider = Provider((ref) => FilterJsService());

class FilterJsService {
  late final JavascriptRuntime engine;
  final Completer<void> _initCompleter = Completer();

  FilterJsService() {
    engine = getJavascriptRuntime();
    _initEngine();
  }

  void _initEngine() {
    // Add polyfills or shared logic if needed
    // Minimal setup for performance
    engine.evaluate('''
       const console = {
         log: (msg) => sendMessage('log', JSON.stringify({msg: msg})),
       };
    ''');

    engine.onMessage('log', (dynamic args) {
      debugPrint('FilterJS: $args');
    });

    _initCompleter.complete();
  }

  Future<bool> evaluate(String script, HttpFlow flow) async {
    await _initCompleter.future;

    // Inject flow data
    final reqMap = flow.request?.toJsMap() ?? {};
    final resMap = flow.response?.toJsMap() ?? {};
    // Debug logging
    debugPrint('JS_FILTER: Evaluating script on flow ${flow.id}');
    debugPrint('JS_FILTER: Script: $script');
    // debugPrint('JS_FILTER: Req: $reqMap');

    // We use a lighter context setup than full JS Engine
    final contextScript =
        '''
      var req = ${jsonEncode(reqMap)};
      var res = ${jsonEncode(resMap)};
    ''';

    final contextResult = engine.evaluate(contextScript);
    if (contextResult.isError) {
      debugPrint('JS_FILTER: Context Error: ${contextResult.stringResult}');
      return false;
    }

    // Evaluate filter script
    // The user script is expected to define "function filter(req, res) { ... }"
    final wrapperScript =
        '''
      (function() {
        try {
           // 1. Evaluate user code (defines the function)
           $script
           
           // 2. Check if filter is defined
           if (typeof filter !== 'function') {
              return "ERROR: 'filter' function not found. Please define function filter(req, res) { ... }";
           }
           
           // 3. Call it
           var result = filter(req, res);
           return result;
        } catch (e) {
           console.log("Error: " + e);
           return "ERROR: " + e;
        }
      })();
    ''';

    final evalResult = engine.evaluate(wrapperScript);

    if (evalResult.isError) {
      debugPrint('JS_FILTER: Eval Error: ${evalResult.stringResult}');
      return false;
    }

    final resultStr = evalResult.stringResult;
    // debugPrint('JS_FILTER: Result: $resultStr');

    if (resultStr.startsWith("ERROR:")) {
      debugPrint('JS_FILTER: Script Error: $resultStr');
      return false;
    }

    // Check truthiness
    return resultStr == 'true';
  }

  void dispose() {
    engine.dispose();
  }
}

import 'dart:convert';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/env_service.dart';
import 'package:api_craft/core/services/req_service.dart';
import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jsEngineProvider = Provider((ref) => JsEngineService(ref));
// for macos: sendMessage,for windows: SendMessage
const sendMsg = "sendMessage";

class JsEngineService {
  final Ref ref;
  JsEngineService(this.ref);

  Future<void> executeScript(
    String script, {
    RawHttpResponse? response,
    BuildContext? context,
  }) async {
    final JavascriptRuntime jsRuntime = getJavascriptRuntime();
    int pendingOps = 0;
    bool scriptExecuted = false;

    void tryDispose() {
      if (pendingOps == 0 && scriptExecuted) {
        jsRuntime.dispose();
      }
    }

    void registerAsyncHandler(
      String channel,
      Future<dynamic> Function(Map args) handler,
    ) {
      jsRuntime.onMessage(channel, (dynamic args) {
        Map<String, dynamic> mapArgs = {};
        if (args is String) {
          try {
            mapArgs = jsonDecode(args);
          } catch (e) {
            /* ignore */
          }
        } else if (args is Map) {
          mapArgs = Map<String, dynamic>.from(args);
        }

        final String? callbackId = mapArgs['callbackId'];
        if (callbackId == null) {
          // Fallback for fire-and-forget or legacy calls
          handler(mapArgs);
          return;
        }

        pendingOps++;
        handler(mapArgs)
            .then((value) {
              final safeValue = jsonEncode(value);
              jsRuntime.evaluate(
                "api._resolveCallback('$callbackId', $safeValue)",
              );
            })
            .catchError((e) {
              debugPrint("JS: Async handler error $e");
              jsRuntime.evaluate("api._rejectCallback('$callbackId', '$e')");
            })
            .whenComplete(() {
              pendingOps--;
              tryDispose();
            });
      });
    }

    try {
      // 1. Inject API bridge
      final syncHandlers = {
        'setVariable': (Map args) {
          final String key = args['key'];
          final dynamic value = args['value'];
          debugPrint('JS: Setting variable $key = $value');
          EnvService.setVariable(ref, key: key, value: value?.toString() ?? '');
        },
        'getVariable': (Map args) {
          final String key = args['key'];
          return EnvService.getVariable(ref, key);
        },
        'getReqUrl': (Map args) {
          return ReqService.getUrl(ref, args['id']);
        },
        'setReqUrl': (Map args) {
          ReqService.setUrl(ref, args['id'], args['url']);
        },
        'getReqMethod': (Map args) {
          return ReqService.getMethod(ref, args['id']);
        },
        'setReqMethod': (Map args) {
          ReqService.setMethod(ref, args['id'], args['method']);
        },
        'getReqHeaders': (Map args) {
          return jsonEncode(ReqService.getHeaders(ref, args['id']));
        },
        'log': (Map args) {
          final String msg = args['msg'];
          debugPrint('JS: $msg');
        },
      };

      syncHandlers.forEach((channel, handler) {
        jsRuntime.onMessage(channel, (dynamic args) {
          Map<String, dynamic> mapArgs = {};
          if (args is String) {
            try {
              mapArgs = jsonDecode(args);
            } catch (e) {
              /* ignore */
            }
          } else if (args is Map) {
            mapArgs = Map<String, dynamic>.from(args);
          }
          return handler(mapArgs);
        });
      });

      // Async Handlers
      registerAsyncHandler('prompt', (Map args) async {
        if (context == null) return null;
        final String msg = args['msg'] ?? 'Prompt';
        final String? value = await showInputDialog(
          context: context,
          title: msg,
        );
        return value;
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

      final currentId = ref.read(activeReqIdProvider) ?? "";

      final String bridge =
          """
        function _send(channel, args) {
           var payload = JSON.stringify(args || {});
           if (typeof $sendMsg !== 'undefined') {
              return $sendMsg(channel, payload);
           } else if (typeof sendMessage !== 'undefined') {
              return sendMessage(channel, payload);
           } else if (typeof SendMessage !== 'undefined') {
              return SendMessage(channel, payload);
           }
           return null;
        }

        // Async Helper
        var _callbacks = {};
        
        function _callAsync(channel, args) {
           return new Promise(function(resolve, reject) {
              var id = 'cb_' + Math.random().toString(36).substr(2, 9);
              _callbacks[id] = { resolve: resolve, reject: reject };
              _send(channel, Object.assign({}, args, {callbackId: id}));
           });
        }
        
        // Console Log Polyfill
        console.log = function(msg) { return _send('log', { msg: msg }); };
        var log = function(msg) { return _send('log', { msg: msg }); };

        // Prompt Polyfill (Async)
        var prompt = function(msg) {
           return _callAsync('prompt', { msg: msg });
        };

        function createReq(id) {
           return {
             id: id,
             getUrl: function() { return _send('getReqUrl', {id: this.id}); },
             setUrl: function(url) { return _send('setReqUrl', {id: this.id, url: url}); },
             getMethod: function() { return _send('getReqMethod', {id: this.id}); },
             setMethod: function(method) { return _send('setReqMethod', {id: this.id, method: method}); },
             getHeaders: function() { 
                var res = _send('getReqHeaders', {id: this.id});
                try { return JSON.parse(res); } catch(e) { return {}; }
             }
           };
        }

        var api = {
          response: $responseJson,
          setVariable: function(key, value) {
            return _send('setVariable', { key: key, value: value });
          },
          getVariable: function(key) {
            return _send('getVariable', { key: key });
          },
          getReq: function(id) {
            return createReq(id);
          },
          _resolveCallback: function(id, value) {
             if (_callbacks[id]) {
                _callbacks[id].resolve(value);
                delete _callbacks[id];
             }
          },
          _rejectCallback: function(id, error) {
             if (_callbacks[id]) {
                _callbacks[id].reject(error);
                delete _callbacks[id];
             }
          }
        };
        
        var req = createReq('$currentId');
      """;

      // 2. Execute
      final result = jsRuntime.evaluate(
        """$bridge \n\n async function main() { $script }\n\n main();""",
      );
      if (result.isError) {
        debugPrint('JS Script Error: ${result.stringResult}');
      }
    } catch (e) {
      debugPrint('JS Runtime Error: $e');
    } finally {
      scriptExecuted = true;
      // Small delay default, but respect pendingOps
      Future.delayed(const Duration(milliseconds: 500), () {
        tryDispose();
      });
    }
  }
}

// const name = await prompt();
// console.log(`name is: ${name}`);
// prompt("name").then(n=>log(`your name is : ${n}`))

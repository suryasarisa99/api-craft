import 'dart:convert';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/env_service.dart';
import 'package:api_craft/core/services/req_service.dart';
import 'package:api_craft/core/services/toast_service.dart';
import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonner_toast/sonner_toast.dart';

final jsEngineProvider = Provider((ref) => JsEngineService(ref));
// for macos: sendMessage,for windows: SendMessage
const sendMsg = "sendMessage";

class JsEngineService {
  final Ref ref;
  JsEngineService(this.ref);

  Future<void> executeScript(
    String script, {
    RawHttpResponse? response,
    required BuildContext context,
  }) async {
    final JavascriptRuntime jsRuntime = getJavascriptRuntime();
    int pendingOps = 0;
    bool scriptExecuted = false; // "started"
    bool scriptFinished = false; // "completed"

    void tryDispose() {
      if (pendingOps == 0 && scriptFinished) {
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
      // 0. Pre-load Active Cookie Jar
      final repo = ref.read(dataRepositoryProvider);
      final collection = ref.read(selectedCollectionProvider);
      final jar = ref.read(environmentProvider).selectedCookieJar;

      // 1. Inject API bridge
      final syncHandlers = {
        'done': (Map args) {
          scriptFinished = true;
          // Defer disposal significantly to ensure evaluate() and channel return paths are clear
          Future.delayed(const Duration(milliseconds: 100), tryDispose);
        },
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
          debugPrint('JS: Getting request URL ${args['id']}');
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
        'setReqBody': (Map args) {
          final body = args['body'];
          final bodyStr = body is String ? body : jsonEncode(body);
          ReqService.setBody(ref, args['id'], bodyStr);
        },
        'setReqHeaders': (Map args) {
          final rawHeaders = args['headers'];
          final headers = <String, String>{};
          if (rawHeaders is Map) {
            rawHeaders.forEach((k, v) {
              headers[k.toString()] = v?.toString() ?? '';
            });
          }
          ReqService.setHeaders(ref, args['id'], headers);
        },
        'log': (Map args) {
          final String msg = args['msg'];
          debugPrint('JS: $msg');
        },
        'toast': (Map args) {
          final dynamic msgRaw = args['msg'];
          String msg;
          if (msgRaw is String) {
            msg = msgRaw;
          } else if (msgRaw is Map || msgRaw is List) {
            try {
              msg = jsonEncode(msgRaw);
            } catch (e) {
              msg = msgRaw.toString();
            }
          } else {
            msg = msgRaw?.toString() ?? 'null';
          }
          final String type = args['type'];
          final String? description = args['description'];
          final int? durationSec = args['duration'];
          final duration = durationSec != null
              ? Duration(seconds: durationSec)
              : null;

          final toastType = ToastType.values.firstWhere(
            (e) => e.name == type,
            orElse: () => ToastType.info,
          );

          debugPrint("JS: Toast $msg $type $description $duration");

          Sonner.toast(
            duration: duration,
            builder: (context, close) => StandardToast(
              message: msg,
              description: description,
              type: toastType,
              onDismiss: close,
            ),
          );
        },
        // Cookie Handlers
        'getCookie': (Map args) {
          if (jar == null) return null;
          final String key = args['key'];
          debugPrint("JS: Getting cookie $key");
          final cookie = jar.cookies.where((c) => c.key == key).firstOrNull;
          return cookie != null ? jsonEncode(cookie.toMap()) : null;
        },
        'getCookieByPath': (Map args) {
          if (jar == null) return null;
          final String path = args['path'];
          final cookies = jar.cookies
              .where((c) => c.path == path)
              .map((e) => e.toMap())
              .toList();
          return jsonEncode(cookies);
        },
        'getAllCookies': (Map args) {
          if (jar == null) return [];
          return jsonEncode(jar.cookies.map((e) => e.toMap()).toList());
        },
        'addCookie': (Map args) {
          if (jar == null) return;
          debugPrint("JS: Adding cookie map $args");
          final newCookie = CookieDef.fromMap(Map<String, dynamic>.from(args));
          debugPrint("JS: Adding cookie object ${newCookie.toMap()}");

          final updatedCookies = jar!.cookies.where((c) {
            final sameKey = c.key == newCookie.key;
            final sameDomain = c.domain == newCookie.domain;
            final samePath = c.path == newCookie.path;
            return !(sameKey && sameDomain && samePath);
          }).toList();

          updatedCookies.add(newCookie);
          final newJar = jar.copyWith(cookies: updatedCookies);
          repo.updateCookieJar(newJar);
        },
        'updateCookie': (Map args) {
          if (jar == null) return;
          final newCookie = CookieDef.fromMap(Map<String, dynamic>.from(args));

          final updatedCookies = jar!.cookies.where((c) {
            final sameKey = c.key == newCookie.key;
            final sameDomain = c.domain == newCookie.domain;
            final samePath = c.path == newCookie.path;
            return !(sameKey && sameDomain && samePath);
          }).toList();

          updatedCookies.add(newCookie);
          final newJar = jar.copyWith(cookies: updatedCookies);
          repo.updateCookieJar(newJar);
        },
        'removeCookie': (Map args) {
          if (jar == null) return;
          final String key = args['key'];
          final updatedCookies = jar.cookies
              .where((c) => c.key != key)
              .toList();
          final newJar = jar.copyWith(cookies: updatedCookies);
          repo.updateCookieJar(newJar);
        },
      };

      final asyncHandlers = {
        'getReqBody': (Map args) {
          return ReqService.getBody(ref, args['id']);
        },
        'prompt': (Map args) async {
          final String msg = args['msg'] ?? 'Prompt';
          final String? value = await showInputDialog(
            context: context,
            title: msg,
          );
          return value;
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

      asyncHandlers.forEach((channel, handler) {
        registerAsyncHandler(channel, handler);
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

        var _callbacks = {};
        function _callAsync(channel, args) {
           return new Promise(function(resolve, reject) {
              var id = 'cb_' + Math.random().toString(36).substr(2, 9);
              _callbacks[id] = { resolve: resolve, reject: reject };
              _send(channel, Object.assign({}, args, {callbackId: id}));
           });
        }
        
        console.log = function(msg) { return _send('log', { msg: msg }); };
        var log = function(msg) { return _send('log', { msg: msg }); };
        var prompt = function(msg) { return _callAsync('prompt', { msg: msg }); };

        function getReq(id) {
           return {
             id: id,
             getUrl: function() { return _send('getReqUrl', {id: this.id}); },
             setUrl: function(url) { return _send('setReqUrl', {id: this.id, url: url}); },
             getMethod: function() { return _send('getReqMethod', {id: this.id}); },
             setMethod: function(method) { return _send('setReqMethod', {id: this.id, method: method}); },
             getHeaders: function() { 
                var res = _send('getReqHeaders', {id: this.id});
                try { return JSON.parse(res); } catch(e) { return {}; }
             },
             setHeaders: function(headers) { return _send('setReqHeaders', {id: this.id, headers: headers}); },
             getBody: function() { return _callAsync('getReqBody', {id: this.id}); },
             setBody: function(body) { return _send('setReqBody', {id: this.id, body: body}); }
           };
        }

        var api = {
          response: $responseJson,
          setVariable: function(key, value) { return _send('setVariable', { key: key, value: value }); },
          getVariable: function(key) { return _send('getVariable', { key: key }); },
          getReq: function(id) { return getReq(id); },
          _resolveCallback: function(id, value) {
             if (_callbacks[id]) { _callbacks[id].resolve(value); delete _callbacks[id]; }
          },
          _rejectCallback: function(id, error) {
             if (_callbacks[id]) { _callbacks[id].reject(error); delete _callbacks[id]; }
          }
        };

        var toast = {
          success: function(msg, options) { var opts = options || {}; return _send('toast', { type: 'success', msg: msg, description: opts.description, duration: opts.duration }); },
          error: function(msg, options) { var opts = options || {}; return _send('toast', { type: 'error', msg: msg, description: opts.description, duration: opts.duration }); },
          warn: function(msg, options) { var opts = options || {}; return _send('toast', { type: 'warning', msg: msg, description: opts.description, duration: opts.duration }); },
          info: function(msg, options) { var opts = options || {}; return _send('toast', { type: 'info', msg: msg, description: opts.description, duration: opts.duration }); },
        };

        var jar = {
          get: function(key) { var res = _send('getCookie', {key: key}); try { return JSON.parse(res); } catch(e) { return null; } },
          getByPath: function(path) { var res = _send('getCookieByPath', {path: path}); try { return JSON.parse(res); } catch(e) { return []; } },
          getAll: function() { var res = _send('getAllCookies', {}); try { return JSON.parse(res); } catch(e) { return []; } },
          add: function(cookie) { return _send('addCookie', cookie); },
          update: function(cookie) { return _send('updateCookie', cookie); },
          remove: function(key) { return _send('removeCookie', {key: key}); }
        };
        
        var req = getReq('$currentId');
      """;

      final result = jsRuntime.evaluate("""$bridge \n\n async function main() { 
             try { 
                $script 
             } catch(e) { 
                _send('toast', {type:'error', msg:'Runtime Error', description: e.toString()}); 
             } finally {
                _send('done');
             }
        }\n\n main(); 0;""");

      if (result.isError) {
        final errorMsg = 'JS Script Error: ${result.stringResult}';
        debugPrint(errorMsg);
        ToastService.error(
          "Script Execution Failed",
          description: result.stringResult,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      final errorMsg = 'JS Runtime Error: $e';
      debugPrint(errorMsg);
      ToastService.error(
        "Script Runtime Error",
        description: e.toString(),
        duration: const Duration(seconds: 5),
      );
    } finally {
      scriptExecuted = true;
      // Use fallback timeout in case done signal is missed (e.g. native crash or extreme freeze)
      Future.delayed(const Duration(seconds: 30), () {
        if (!scriptFinished) {
          debugPrint("JS: Script timed out. Disposing.");
          scriptFinished = true;
          tryDispose();
        }
      });
    }
  }
}

// const name = await prompt();
// console.log(`name is: ${name}`);
// prompt("name").then(n=>log(`your name is : ${n}`))

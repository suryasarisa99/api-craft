import 'dart:async';
import 'dart:convert';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/network/raw/raw_http_req.dart';
import 'package:api_craft/features/console/models/console_log_entry.dart';
import 'package:api_craft/features/console/providers/console_logs_provider.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/providers/ref_provider.dart';
import 'package:api_craft/core/services/env_service.dart';
import 'package:api_craft/core/services/req_service.dart';
import 'package:api_craft/core/services/toast_service.dart';
import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:api_craft/features/request/services/http_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonner_toast/sonner_toast.dart';

final jsEngineProvider = Provider((ref) => JsEngineService(ref));

// for macos: sendMessage, for windows: SendMessage
const sendMsg = "sendMessage";

class JsEngineService {
  final Ref ref;
  JsEngineService(this.ref);

  Future<void> executeScript(
    String script, {
    RawHttpResponse? response,
    required BuildContext context,
  }) async {
    final JavascriptRuntime engine = getJavascriptRuntime();
    final Completer<void> scriptCompleter = Completer();
    debugPrint("===: Executing script");

    // 1. Define Bridge Handlers
    // The key is the channel name.
    // The value is the handler function which can be async and return a value directly.
    final handlers = <String, FutureOr<dynamic> Function(Map<String, dynamic>)>{
      'log': (args) {
        final list = args['args'] ?? [args['msg']?.toString() ?? ''];
        debugPrint('JS:log: $list');
        ref
            .read(consoleLogsProvider.notifier)
            .log(list, source: ConsoleLogSource.javascript);
      },
      'debug': (args) {
        final list = args['args'] ?? [args['msg']?.toString() ?? ''];
        ref
            .read(consoleLogsProvider.notifier)
            .debug(list, source: ConsoleLogSource.javascript);
      },
      'error': (args) {
        final list = args['args'] ?? [args['msg']?.toString() ?? ''];
        ref
            .read(consoleLogsProvider.notifier)
            .error(list, source: ConsoleLogSource.javascript);
      },
      'warn': (args) {
        final list = args['args'] ?? [args['msg']?.toString() ?? ''];
        ref
            .read(consoleLogsProvider.notifier)
            .warn(list, source: ConsoleLogSource.javascript);
      },
      'info': (args) {
        final list = args['args'] ?? [args['msg']?.toString() ?? ''];
        ref
            .read(consoleLogsProvider.notifier)
            .info(list, source: ConsoleLogSource.javascript);
      },
      'script_done': (args) {
        if (!scriptCompleter.isCompleted) {
          scriptCompleter.complete();
        }
      },
      'setVar': (args) {
        EnvService.setVariable(
          ref,
          key: args['key'],
          value: args['value']?.toString() ?? '',
        );
      },
      'getVar': (args) {
        return EnvService.getVariable(ref, args['key']);
      },
      'getReqUrl': (args) {
        return ReqService.getUrl(ref, args['id']);
      },
      'setReqUrl': (args) {
        ReqService.setUrl(ref, args['id'], args['url']);
      },
      'getReqMethod': (args) {
        return ReqService.getMethod(ref, args['id']);
      },
      'setReqMethod': (args) {
        ReqService.setMethod(ref, args['id'], args['method']);
      },
      'getReqBody': (args) async {
        final body = await ReqService.getBody(ref, args['id']);
        if (body is Map || body is List) return jsonEncode(body);
        return body?.toString();
      },
      'setReqBody': (args) {
        final body = args['body'];
        final bodyStr = body is String ? body : jsonEncode(body);
        ReqService.setBody(ref, args['id'], bodyStr);
      },
      'setReqHeaders': (args) {
        final rawHeaders = args['headers'];
        final headers = <String, String>{};
        if (rawHeaders is Map) {
          rawHeaders.forEach(
            (k, v) => headers[k.toString()] = v?.toString() ?? '',
          );
        }
        ReqService.setHeaders(ref, args['id'], headers);
      },
      'setReqHeader': (args) {
        final id = args['id'];
        final key = args['key'];
        final value = args['value'];
        if (id != null && key != null) {
          final node = ref.read(fileTreeProvider).nodeMap[id];
          if (node is RequestNode) {
            final headers = List<KeyValueItem>.from(node.config.headers);
            final matchKey = key.toString().toLowerCase();
            int index = -1;

            // Search from last
            for (var i = headers.length - 1; i >= 0; i--) {
              if (headers[i].isEnabled &&
                  headers[i].key.toLowerCase() == matchKey) {
                index = i;
                break;
              }
            }

            if (index != -1) {
              debugPrint("Found header: $key");
              // Replace value
              headers[index] = headers[index].copyWith(
                value: value?.toString() ?? '',
              );
            } else {
              // Add new
              headers.add(
                KeyValueItem(key: key, value: value?.toString() ?? ''),
              );
            }
            ref
                .read(fileTreeProvider.notifier)
                .updateHeaders(id, List<KeyValueItem>.from(headers));
          }
        }
      },
      'addReqHeader': (args) {
        final id = args['id'];
        final key = args['key'];
        final value = args['value'];
        if (id != null && key != null) {
          final node = ref.read(fileTreeProvider).nodeMap[id];
          if (node is RequestNode) {
            final headers = List<KeyValueItem>.from(node.config.headers);
            headers.add(KeyValueItem(key: key, value: value?.toString() ?? ''));
            ref.read(fileTreeProvider.notifier).updateHeaders(id, headers);
          }
        }
      },
      'addReqHeaders': (args) {
        final id = args['id'];
        final dynamic newHeaders = args['headers'];
        if (id != null && newHeaders != null) {
          final node = ref.read(fileTreeProvider).nodeMap[id];
          if (node is RequestNode) {
            final headers = List<KeyValueItem>.from(node.config.headers);
            if (newHeaders is Map) {
              newHeaders.forEach((k, v) {
                headers.add(
                  KeyValueItem(key: k.toString(), value: v?.toString() ?? ''),
                );
              });
            } else if (newHeaders is List) {
              for (var h in newHeaders) {
                if (h is Map) {
                  headers.add(
                    KeyValueItem(
                      key: h['key']?.toString() ?? '',
                      value: h['value']?.toString() ?? '',
                    ),
                  );
                }
              }
            }
            ref.read(fileTreeProvider.notifier).updateHeaders(id, headers);
          }
        }
      },
      'getReqHeaders': (args) {
        final node = ref.read(fileTreeProvider).nodeMap[args['id']];
        final List<Map<String, String>> headersList = [];
        if (node is RequestNode) {
          for (final h in node.config.headers) {
            if (h.isEnabled) headersList.add({'key': h.key, 'value': h.value});
          }
        }
        return jsonEncode(headersList);
      },
      'getReqHeadersMap': (args) {
        return jsonEncode(ReqService.getHeaders(ref, args['id']));
      },
      'getResolvedReq': (args) async {
        final id = args['id'];
        if (id != null) {
          final resolved = await ref
              .read(requestResolverProvider)
              .resolveForExecution(id, context: context);
          return jsonEncode(resolved.toMap());
        }
        return null;
      },
      'getReqHeader': (args) {
        final node = ref.read(fileTreeProvider).nodeMap[args['id']];
        final key = args['key']?.toString().toLowerCase();
        if (node is RequestNode && key != null) {
          // Search from last
          for (var i = node.config.headers.length - 1; i >= 0; i--) {
            final h = node.config.headers[i];
            if (h.isEnabled && h.key.toLowerCase() == key) {
              return h.value;
            }
          }
        }
        return null;
      },
      'toast': (args) {
        final dynamic msgRaw = args['msg'];
        String msg;
        debugPrint("Toast: ${msgRaw.runtimeType}");
        if (msgRaw is String) {
          msg = msgRaw;
        } else {
          try {
            msg = jsonEncode(msgRaw);
          } catch (_) {
            msg = msgRaw?.toString() ?? 'null';
          }
        }

        final String type = args['type'];
        final String? description = args['description'];
        final duration = Duration(seconds: args['duration'] ?? 4);

        final toastType = ToastType.values.firstWhere(
          (e) => e.name == type,
          orElse: () => ToastType.info,
        );

        // Log to console
        final level = toastType == ToastType.error
            ? ConsoleLogLevel.error
            : toastType == ToastType.warning
            ? ConsoleLogLevel.warning
            : ConsoleLogLevel.info;

        ref
            .read(consoleLogsProvider.notifier)
            .add(
              ConsoleLogEntry(
                timestamp: DateTime.now(),
                level: level,
                source: ConsoleLogSource.system,
                args: [msg, if (description != null) description],
              ),
            );

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
      'prompt': (args) async {
        final msg = args['msg'] ?? 'Prompt';
        return await showInputDialog(context: context, title: msg);
      },
      'resolveId': (args) {
        final target = args['id'];
        final contextId = args['contextId'];
        if (target == null) return null;
        return _resolveNodeId(target.toString(), contextId: contextId);
      },
      // Cookie Handlers
      'getCookie': (args) {
        final jar = ref.read(environmentProvider).selectedCookieJar;
        if (jar != null) {
          final c = jar.cookies.where((c) => c.key == args['key']).firstOrNull;
          return c != null ? jsonEncode(c.toMap()) : null;
        }
        return null;
      },
      'addCookie': (args) {
        final repo = ref.read(dataRepositoryProvider);
        final jar = ref.read(environmentProvider).selectedCookieJar;
        if (jar != null) {
          final newCookie = CookieDef.fromMap(args);
          final updated = jar.cookies
              .where(
                (c) =>
                    !(c.key == newCookie.key &&
                        c.domain == newCookie.domain &&
                        c.path == newCookie.path),
              )
              .toList();
          updated.add(newCookie);
          repo.updateCookieJar(jar.copyWith(cookies: updated));
        }
      },
      'updateCookie': (args) {
        // Same as add for now
        final repo = ref.read(dataRepositoryProvider);
        final jar = ref.read(environmentProvider).selectedCookieJar;
        if (jar != null) {
          final newCookie = CookieDef.fromMap(args);
          final updated = jar.cookies
              .where(
                (c) =>
                    !(c.key == newCookie.key &&
                        c.domain == newCookie.domain &&
                        c.path == newCookie.path),
              )
              .toList();
          updated.add(newCookie);
          repo.updateCookieJar(jar.copyWith(cookies: updated));
        }
      },
      'removeCookie': (args) {
        final repo = ref.read(dataRepositoryProvider);
        final jar = ref.read(environmentProvider).selectedCookieJar;
        if (jar != null) {
          final key = args['key'];
          final updated = jar.cookies.where((c) => c.key != key).toList();
          repo.updateCookieJar(jar.copyWith(cookies: updated));
        }
      },
      'runRequest': (args) async {
        final path = args['path'];
        final contextId = args['contextId'];
        if (path is String) {
          final id = _resolveNodeId(path, contextId: contextId);
          if (id != null) {
            /*
            running request, triggers pre script,post script, so same ref cause circular ref
            */
            final r = ref.read(refProvider);
            final response = await HttpService().run(r, id, context: context);
            debugPrint("Response: ${response.body}");
            return jsonEncode({
              'status': response.statusCode,
              'statusText': response.statusMessage,
              'headers': Map.fromEntries(
                response.headers.map((e) => MapEntry(e[0], e[1])),
              ),
              'body': response.body, // Dynamic
              'responseTime': response.durationMs,
            });
          }
        }
        return null;
      },
      'sendRequest': (args) async {
        final method = args['method'] ?? 'GET';
        final url = args['url'];
        final headersRaw = args['headers'];
        final data = args['data']; // body

        if (url == null) throw Exception("URL required");

        final headers = <List<String>>[];
        if (headersRaw is Map) {
          headersRaw.forEach(
            (k, v) => headers.add([k.toString(), v.toString()]),
          );
        }

        final response = await sendRawHttp(
          method: method,
          url: Uri.parse(url),
          headers: headers,
          body: data is Map ? jsonEncode(data) : data?.toString(),
          requestId: 'adhoc',
        );

        return jsonEncode({
          'status': response.statusCode,
          'statusText': response.statusMessage,
          'headers': Map.fromEntries(
            response.headers.map((e) => MapEntry(e[0], e[1])),
          ),
          'body': response.body,
          'responseTime': response.durationMs,
        });
      },
      'setNextRequest': (args) {
        final nextName = args['next'];
        debugPrint("Runner setNextRequest: $nextName");
        // TODO: Wire up to Runner state
      },
    };

    // 2. Register Channels
    handlers.forEach((channel, handler) {
      engine.onMessage(channel, (dynamic args) {
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

    try {
      // 3. Prepare Environment
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

      // 4. Bridge Script - PURE AND SIMPLE
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

        var console = { 
            log: function(...args) { _send('log', {args:args}); },
            debug: function(...args) { _send('debug', {args:args}); },
            error: function(...args) { _send('error', {args:args}); },
            warn: function(...args) { _send('warn', {args:args}); },
            info: function(...args) { _send('info', {args:args}); }
        };
        var log = function(...args) { _send('log', {args:args}); };
        var prompt = async function(msg) { return _send('prompt', {msg: msg}); };
        
        function getReq(idOrPath) {
           var contextId = (typeof req !== 'undefined' && req && req.id) ? req.id : null;
           var resolved = _send('resolveId', {id: idOrPath, contextId: contextId});
           var finalId = resolved || idOrPath;

           return {
             id: finalId,
             getUrl: function() { return _send('getReqUrl', {id: this.id}); },
             getMethod: function() { return _send('getReqMethod', {id: this.id}); },
             
             getResolved: async function() { 
                 var res = await _send('getResolvedReq', {id: this.id});
                 try { return JSON.parse(res); } catch(e) { return null; }
             },

             getBody: async function() { 
                 var res = await _send('getReqBody', {id: this.id});
                 try { return JSON.parse(res); } catch(e) { return res; }
             },
             
             setUrl: function(u) { _send('setReqUrl', {id: this.id, url: u}); },
             setMethod: function(m) { _send('setReqMethod', {id: this.id, method: m}); },
             setBody: function(b) { _send('setReqBody', {id: this.id, body: b}); },

            // Headers
             getHeaders: function() { 
                 var res = _send('getReqHeaders', {id: this.id});
                 try { return JSON.parse(res); } catch(e) { return []; }
             },
             getHeadersMap: function() {
                 var res = _send('getReqHeadersMap', {id: this.id});
                 try { return JSON.parse(res); } catch(e) { return {}; }
             },
             getHeader: function(k) { return _send('getReqHeader', {id: this.id, key: k}); },
             setHeaders: function(h) { _send('setReqHeaders', {id: this.id, headers: h}); },
             setHeader: function(k, v) { _send('setReqHeader', {id: this.id, key: k, value: v}); },
             addHeader: function(k, v) { _send('addReqHeader', {id: this.id, key: k, value: v}); },
             addHeaders: function(h) { _send('addReqHeaders', {id: this.id, headers: h}); }
           };
        }

        var api = {
           response: $responseJson,
           setVar: function(k, v) { _send('setVar', {key:k, value:v}); },
           getVar: function(k) { return _send('getVar', {key:k}); },
           getReq: function(id) { return getReq(id); },
           
           runRequest: async function(path) {
               var res = await _send('runRequest', {path: path, contextId: req.id});
               try { return JSON.parse(res); } catch(e) { return null; }
           },
           sendRequest: async function(opts, callback) {
               try {
                   var res = await _send('sendRequest', opts);
                   var parsed = JSON.parse(res);
                   if (callback) callback(null, parsed);
                   return parsed;
               } catch(e) {
                   if (callback) callback(e, null);
                   throw e;
               }
           },
           setNextRequest: function(next) { _send('setNextRequest', {next: next}); },
           runner: {
               setNextRequest: function(next) { _send('setNextRequest', {next: next}); }
           }
        };

        var bru = api;
        var bruno = api;

        var toast = {
           success: function(m, o) { _send('toast', {type:'success', msg:m, description: o?.description, duration: o?.duration}); },
           error: function(m, o) { _send('toast', {type:'error', msg:m, description: o?.description, duration: o?.duration}); },
           info: function(m, o) { _send('toast', {type:'info', msg:m, description: o?.description, duration: o?.duration}); },
           warn: function(m, o) { _send('toast', {type:'warning', msg:m, description: o?.description, duration: o?.duration}); },
        };

        var req = getReq('$currentId');

        var jar = {
           get: function(k) { 
               var res = _send('getCookie', {key:k});
               try { return res ? JSON.parse(res) : null; } catch(e) { return null; }
           },
           add: function(c) { _send('addCookie', c); },
           update: function(c) { _send('updateCookie', c); },
           remove: function(k) { _send('removeCookie', {key:k}); }
        };
      """;

      // 5. Execute
      final fullScript =
          """
      $bridge
      (async function() {
          try {
              $script
          } catch(e) {
              _send('toast', {type:'error', msg: 'Runtime Error', description: e.toString(), duration: 4});
          } finally {
              _send('script_done');
          }
      })();
      """;

      engine.evaluate(fullScript);

      await scriptCompleter.future;
    } catch (e) {
      debugPrint("JS Engine Logic Error: $e");
      ToastService.error("Script Error", description: e.toString());
    } finally {
      // Delay disposal to prevent native crash on nested executions (macOS/flutter_js issue)
      Future.delayed(const Duration(milliseconds: 500), () {
        engine.dispose();
      });
    }
  }

  static String dynamicToString(dynamic value) {
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return value?.toString() ?? 'null';
  }

  String? _resolveNodeId(String target, {String? contextId}) {
    final nodeMap = ref.read(fileTreeProvider).nodeMap;

    // 0. Check for Direct ID (Legacy/Default support)
    if (nodeMap.containsKey(target)) return target;

    // 1. Check for Direct ID (@id:...)
    if (target.startsWith('@id:')) {
      final id = target.substring(4);
      return nodeMap.containsKey(id) ? id : null;
    }

    // 2. Resolve Paths
    final collectionId = ref.read(selectedCollectionProvider)?.id;
    if (collectionId == null) return null;

    String? currentParentId;
    List<String> segments;

    if (target.startsWith('/')) {
      // Absolute Path from Collection Root
      currentParentId = collectionId;
      segments = target.split('/').where((s) => s.isNotEmpty).toList();
    } else if (target.startsWith('./') || target.startsWith('../')) {
      // Relative Path
      if (contextId == null) {
        currentParentId = collectionId;
        segments = target.split('/').where((s) => s.isNotEmpty).toList();
      } else {
        final contextNode = nodeMap[contextId];
        if (contextNode == null) return null;
        currentParentId = contextNode.parentId ?? collectionId;
        segments = target.split('/').where((s) => s.isNotEmpty).toList();
      }
    } else {
      // Default: Absolute like Bruno
      currentParentId = collectionId;
      segments = target.split('/').where((s) => s.isNotEmpty).toList();
    }

    // Traverse
    for (int i = 0; i < segments.length; i++) {
      final name = segments[i];
      final isLast = i == segments.length - 1;

      if (name == '.') continue;
      if (name == '..') {
        if (currentParentId == collectionId) continue;
        final parentNode = nodeMap[currentParentId];
        currentParentId = parentNode?.parentId ?? collectionId;
        continue;
      }

      Node? match;
      for (final node in nodeMap.values) {
        final pId = node.parentId;
        bool parentMatches = false;
        if (currentParentId == collectionId) {
          parentMatches = (pId == collectionId || pId == null);
        } else {
          parentMatches = (pId == currentParentId);
        }

        if (parentMatches && node.name == name) {
          match = node;
          break;
        }
      }

      if (match == null) return null;

      if (isLast) {
        return match is RequestNode ? match.id : null;
      } else {
        if (match is FolderNode) {
          currentParentId = match.id;
        } else {
          // Path segment is file but not last
          return null;
        }
      }
    }
    return null;
  }
}

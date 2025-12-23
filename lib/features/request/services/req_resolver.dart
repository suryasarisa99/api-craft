import 'dart:developer';

import 'package:api_craft/core/network/header_utils.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
import 'package:api_craft/features/template-functions/parsers/parse.dart';
import 'package:api_craft/features/template-functions/parsers/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestResolver {
  final Ref ref;
  late final RequestHydrator _hydrator = RequestHydrator(ref);

  RequestResolver(this.ref);

  // _LazyVariableResolver? _lazyResolver;

  FolderNode? _parentOf(Node node) {
    return ref.read(fileTreeProvider).nodeMap[node.parentId] as FolderNode?;
  }

  /// ---------- UI RESOLUTION ----------
  Future<UiRequestContext> resolveForUi(String requestId) async {
    debugPrint("resolve for ui: $requestId");
    //callstack
    late Node node;
    try {
      node = ref.read(fileTreeProvider.select((t) => t.nodeMap[requestId]!));
    } catch (e) {
      log("error for id: $requestId: $e", stackTrace: StackTrace.current);
    }

    await _hydrator.hydrateNode(node);
    await _hydrator.hydrateAncestors(node);

    final body = await ref.read(repositoryProvider).getBody(requestId);
    debugPrint("body: $body");

    final inheritedHeaders = _collectInheritedHeaders(node);
    final authResult = _resolveAuth(node);
    final vars = _mergeVariables(node);

    return UiRequestContext(
      node: node,
      body: body,
      inheritedHeaders: inheritedHeaders,
      effectiveAuth: authResult.$1,
      authSource: authResult.$2,
      allVariables: vars,
    );
  }

  Future<Map<String, dynamic>> resolveForTemplatePreview(
    String? requestId,
    Map<String, dynamic> args,
    BuildContext context,
    String? previewType,
  ) async {
    final node =
        ref.read(fileTreeProvider.select((t) => t.nodeMap[requestId]))
            as RequestNode?;
    final mergedVars = _mergeVariables(node);
    final resolver = LazyVariableResolver(mergedVars, this);
    // resolve args values if string
    final resolvedArgs = <String, dynamic>{};
    for (final entry in args.entries) {
      if (entry.value is String) {
        resolvedArgs[entry.key] = await resolveVariables(
          entry.value,
          resolver,
          context: context,
          purpose: Purpose.preview,
          prvType: previewType,
        );
      } else {
        resolvedArgs[entry.key] = entry.value;
      }
    }
    return resolvedArgs;
  }

  /// ---------- EXECUTION RESOLUTION ----------
  Future<ResolvedRequestContext> resolveForExecution(
    String requestId, {
    required BuildContext context,
  }) async {
    final node =
        ref.read(fileTreeProvider.select((t) => t.nodeMap[requestId]!))
            as RequestNode;

    await _hydrator.hydrateNode(node);
    await _hydrator.hydrateAncestors(node);
    final body = await ref.read(repositoryProvider).getBody(requestId);

    final inheritedHeaders = _collectInheritedHeaders(node);
    final auth = _resolveAuth(node).$1;
    final mergedVars = _mergeVariables(node);
    final resolver = LazyVariableResolver(mergedVars, this);

    final resolvedUrl = await resolveVariables(
      node.url,
      resolver,
      context: context,
    );
    final uri = Uri.parse(resolvedUrl);

    final queryParams = await Future.wait(
      cleanKeyValueItems(
        node.config.queryParameters,
        removeEmptyKeys: false,
      ).map((p) async {
        return [
          await resolveVariables(p[0], resolver, context: context),
          await resolveVariables(p[1], resolver, context: context),
        ];
      }).toList(),
    );
    final fullUri = _handleUri(uri, queryParams);

    final headers = await Future.wait(
      _handleHeaders(node.config.headers, inheritedHeaders).map((h) async {
        return [
          await resolveVariables(h[0], resolver, context: context),
          await resolveVariables(h[1], resolver, context: context),
        ];
      }).toList(),
    );

    // Inject Cookies
    final envState = ref.read(environmentProvider);
    final jar = envState.selectedCookieJar;
    if (jar != null) {
      final relevantCookies = jar.cookies.where((c) {
        debugPrint(
          "cookie: ${c.key} enabled: ${c.isEnabled}, domain: ${c.domain}",
        );
        if (!c.isEnabled) return false;
        if (!domainMatches(uri, c)) return false;
        if (!pathMatches(uri, c)) return false;
        if (c.isSecure && uri.scheme != 'https') return false;
        return true;
      });
      debugPrint("relevantCookies: ${relevantCookies.length}");

      if (relevantCookies.isNotEmpty) {
        final cookieHeaderVal = relevantCookies
            .map((c) => '${c.key}=${c.value}')
            .join('; ');
        bool found = false;
        for (var h in headers) {
          if (h[0].toLowerCase() == 'cookie') {
            h[1] = '${h[1]}; $cookieHeaderVal';
            found = true;
            break;
          }
        }
        if (!found) {
          headers.add(['Cookie', cookieHeaderVal]);
        }
      }
    }
    final resolvedAuth = auth.copyWith(
      token: await resolveVariables(auth.token, resolver, context: context),
      username: await resolveVariables(
        auth.username,
        resolver,
        context: context,
      ),
      password: await resolveVariables(
        auth.password,
        resolver,
        context: context,
      ),
    );

    final resolvedBody = body == null
        ? null
        : await resolveVariables(body, resolver, context: context);

    // After all resolution, we can get only the variables that were actually used
    final finalResolvedVars = <String, VariableValue>{};
    for (final key in resolver.resolvedKeys) {
      if (mergedVars.containsKey(key)) {
        finalResolvedVars[key] = VariableValue(
          mergedVars[key]!.sourceId,
          resolver._cache[key]!,
        );
      }
    }

    return ResolvedRequestContext(
      request: node,
      uri: fullUri,
      body: resolvedBody,
      headers: headers,
      auth: resolvedAuth,
      variables: finalResolvedVars,
    );
  }

  bool domainMatches(Uri uri, CookieDef c) {
    if (c.isHostOnly) {
      return uri.host == c.domain;
    }
    return uri.host == c.domain || uri.host.endsWith('.${c.domain}');
  }

  bool pathMatches(Uri uri, CookieDef c) {
    final cookiePath = c.path;
    final reqPath = uri.path.isEmpty ? '/' : uri.path;

    if (cookiePath == '/' || reqPath == cookiePath) return true;

    if (reqPath.startsWith(cookiePath)) {
      if (cookiePath.endsWith('/')) return true;
      if (reqPath[cookiePath.length] == '/') return true;
    }

    return false;
  }

  /// ---------- HELPERS ----------
  List<KeyValueItem> _collectInheritedHeaders(Node node) {
    final result = <KeyValueItem>[];
    Node? ptr = _parentOf(node);
    while (ptr != null) {
      result.insertAll(0, ptr.config.headers.where((h) => h.isEnabled));
      ptr = _parentOf(ptr);
    }
    return result;
  }

  (AuthData, Node?) _resolveAuth(Node node) {
    final current = node.config.auth;
    if (current.type != AuthType.inherit) {
      return (current, node);
    }

    Node? ptr = _parentOf(node);
    while (ptr != null) {
      final auth = ptr.config.auth;
      if (auth.type == AuthType.noAuth) {
        return (const AuthData(type: AuthType.noAuth), null);
      }
      if (auth.type != AuthType.inherit) {
        return (auth, ptr);
      }
      ptr = _parentOf(ptr);
    }

    return (const AuthData(type: AuthType.noAuth), null);
  }

  Map<String, VariableValue> _mergeVariables(Node? node) {
    final result = <String, VariableValue>{};

    // 1. Start with Global Environment Variables (Always Active)
    final envState = ref.read(environmentProvider);
    final globalEnv = envState.globalEnvironment;
    if (globalEnv != null) {
      for (final v in globalEnv.variables) {
        if (v.isEnabled) {
          result[v.key] = VariableValue("global-env", v.value);
        }
      }
    }

    // 2. Overlay Selected Sub-Environment
    final selectedEnv = envState.selectedEnvironment;
    // If selected is Global, we already added it. If it's different (Sub-Env), overlay it.
    if (selectedEnv != null && selectedEnv.id != globalEnv?.id) {
      for (final v in selectedEnv.variables) {
        if (v.isEnabled) {
          result[v.key] = VariableValue("sub-env", v.value);
        }
      }
    }
    // may be resolving for template preview which used in global env
    if (node == null) return result;

    final chain = <FolderNode>[];

    var ptr = _parentOf(node);
    while (ptr != null) {
      chain.insert(0, ptr);
      ptr = _parentOf(ptr);
    }

    // 2. Overlay Folder Chain Variables (Overrides Global)
    for (final folder in chain) {
      for (final v in folder.config.variables) {
        if (v.isEnabled) {
          result[v.key] = VariableValue(folder.id, v.value);
        }
      }
    }
    debugPrint("merged variables: ${result.length}");
    return result;
  }

  /// Old way only handles variables
  // final _variableRegExp = RegExp(r'{{\s*([a-zA-Z0-9_-]+)\s*}}');
  // final _variableRegExp = RegExp(r'{{\s*([^{}\s]+)\s*}}');
  // String _resolveVariables(String text, Map<String, VariableValue> values) {
  //   // Match all {{variable}} patterns
  //   return text.replaceAllMapped(_variableRegExp, (match) {
  //     final key = match.group(1);
  //     if (key != null && values.containsKey(key)) {
  //       return values[key]!.value; // Replace with value
  //     }
  //     return match.group(0)!; // leave as is if no value found
  //   });
  // }

  /// New way handles variables and functions
  Future<String> resolveVariables(
    String text,
    LazyVariableResolver resolver, {
    required BuildContext context,
    Purpose purpose = Purpose.send,
    String? prvType,
  }) async {
    final placeholders = TemplateParser.parseAll(text)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final placeholder in placeholders) {
      if (placeholder is TemplateFnPlaceholder) {
        final fn = getTemplateFunctionByName(placeholder.name);

        if (purpose == Purpose.preview &&
            fn?.previewType == 'click' &&
            prvType != 'click') {
          // return text;
          throw Exception(
            'Preview not supports, because of using click previewType function',
          );
        }

        // Resolve function arguments if they are strings
        final resolvedArgs = <String, dynamic>{};
        if (placeholder.args != null) {
          for (final entry in placeholder.args!.entries) {
            final val = entry.value;
            if (val is String) {
              resolvedArgs[entry.key] = await resolveVariables(
                val,
                resolver,
                context: context,
              );
            } else {
              resolvedArgs[entry.key] = val;
            }
          }
        }

        final String? fnValue = await fn?.onRender(
          ref,
          context,
          CallTemplateFunctionArgs(values: resolvedArgs, purpose: purpose),
        );
        text = text.replaceRange(
          placeholder.start,
          placeholder.end,
          fnValue ?? '',
        );
      } else {
        final key = placeholder.name;
        if (resolver.hasVariable(key)) {
          final val = await resolver.resolve(key, context: context);
          text = text.replaceRange(placeholder.start, placeholder.end, val);
        }
      }
    }
    return text;
  }

  List<List<String>> cleanKeyValueItems(
    List<KeyValueItem> items, {
    bool trimValues = true,
    bool removeEmptyKeys = true,
  }) {
    final List<List<String>> cleanedItems = [];
    for (var item in items) {
      if (!item.isEnabled) continue;
      final key = item.key.trim();
      final value = trimValues ? item.value.trim() : item.value;
      final keyIsEmpty = key.isEmpty;
      if (keyIsEmpty && value.isEmpty) continue;
      if (removeEmptyKeys && key.isEmpty) continue;
      cleanedItems.add([key, value]);
    }
    return cleanedItems;
  }

  List<List<String>> _handleHeaders(
    List<KeyValueItem> headers,
    List<KeyValueItem> inherited,
  ) {
    final merged = [
      ...cleanKeyValueItems(inherited),
      ...cleanKeyValueItems(headers),
    ];
    return HeaderUtils.handleHeaders(merged);
  }

  Uri _handleUri(Uri url, List<List<String>> params) {
    final paramsStr = params
        .map((p) => '${Uri.encodeComponent(p[0])}=${Uri.encodeComponent(p[1])}')
        .join('&');
    return paramsStr.isNotEmpty
        ? url.replace(
            query: url.query.isNotEmpty ? "${url.query}&$paramsStr" : paramsStr,
          )
        : url;
  }

  // Uri _handleUri2(Uri url, List<List<String>> params) {
  //   final buffer = StringBuffer();

  //   // 1️⃣ Existing query from URL (as-is, but normalized)
  //   if (url.hasQuery) {
  //     final existing = url.query.split('&').where((e) => e.isNotEmpty);
  //     for (final q in existing) {
  //       if (buffer.isNotEmpty) buffer.write('&');
  //       buffer.write(q);
  //     }
  //   }

  //   // 2️⃣ Append KV params (duplicates allowed)
  //   for (final p in params) {
  //     if (p.length != 2) continue;

  //     final key = p[0];
  //     if (key.isEmpty) continue;

  //     final value = p[1];

  //     if (buffer.isNotEmpty) buffer.write('&');
  //     buffer.write(
  //       '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
  //     );
  //   }

  //   // 3️⃣ Replace query
  //   return buffer.isEmpty ? url : url.replace(query: buffer.toString());
  // }
}

class LazyVariableResolver {
  final Map<String, VariableValue> _rawVars;
  final Map<String, String> _cache = {};
  final RequestResolver _resolver;
  final Set<String> _resolving = {}; // To prevent circular dependencies
  final Set<String> resolvedKeys = {}; // Track which keys were requested

  LazyVariableResolver(this._rawVars, this._resolver);

  Future<String> resolve(String key, {required BuildContext context}) async {
    resolvedKeys.add(key);
    debugPrint("Resolving variable: $key");
    if (_cache.containsKey(key)) {
      debugPrint("Returning cached value for: $key");
      return _cache[key]!;
    }
    if (_resolving.contains(key)) {
      debugPrint("Circular dependency detected for variable: $key");
      return '{{$key}}'; // Or some other fallback
    }

    _resolving.add(key);
    try {
      final value = _rawVars[key]?.value;
      if (value == null) return '{{$key}}';

      if (value is String) {
        final resolved = await _resolver.resolveVariables(
          value,
          this,
          context: context,
        );
        _cache[key] = resolved;
        return resolved;
      } else {
        final resolved = value.toString();
        _cache[key] = resolved;
        return resolved;
      }
    } finally {
      _resolving.remove(key);
    }
  }

  bool hasVariable(String key) => _rawVars.containsKey(key);
}

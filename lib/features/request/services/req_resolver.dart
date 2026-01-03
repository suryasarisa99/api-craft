import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:api_craft/core/network/header_utils.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/request/models/inherited_request_model.dart';
import 'package:api_craft/features/request/widgets/tabs/tab_titles.dart';
import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
import 'package:api_craft/features/template-functions/parsers/parse.dart';
import 'package:api_craft/features/template-functions/parsers/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final requestResolverProvider = Provider((ref) => RequestResolver(ref));

class RequestResolver {
  final Ref ref;
  late final RequestHydrator _hydrator = RequestHydrator(ref);

  RequestResolver(this.ref);

  FolderNode? _parentOf(Node node) {
    return ref.read(fileTreeProvider).nodeMap[node.parentId] as FolderNode?;
  }

  /// ---------- UI RESOLUTION ----------
  Future<InheritedRequest> resolveInherit(String requestId) async {
    debugPrint("resolve for ui: $requestId");
    //callstack
    late Node node;
    try {
      node = ref.read(fileTreeProvider.select((t) => t.nodeMap[requestId]!));
    } catch (e) {
      log("error for id: $requestId: $e", stackTrace: StackTrace.current);
    }

    // await _hydrator.hydrateNode(node);
    await _hydrator.hydrateAncestors(node);

    final inheritedHeaders = collectInheritedHeaders(node);
    final authResult = resolveAuth(node);
    final vars = mergeVariables(node);

    return InheritedRequest(
      headers: inheritedHeaders,
      auth: authResult.$1,
      authSource: authResult.$2,
      variables: vars,
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
    final mergedVars = mergeVariables(node);
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

    await _hydrator.hydrateNode(node.id);
    await _hydrator.hydrateAncestors(node);
    final bodyStr = await ref.read(repositoryProvider).getBody(requestId);

    final inheritedHeaders = collectInheritedHeaders(node);
    final auth = resolveAuth(node).$1;
    final mergedVars = mergeVariables(node);
    final resolver = LazyVariableResolver(mergedVars, this);

    // Resolve Body & Content-Type Headers
    (dynamic, List<List<String>>?) bodyResult;
    if (node.config.bodyType == BodyType.graphql) {
      bodyResult = await _resolveGraphqlBody(bodyStr, resolver, context);
    } else {
      bodyResult = await _resolveBody(
        bodyStr,
        node.config.bodyType,
        resolver,
        context,
      );
    }

    final resolvedBody = bodyResult.$1;
    final contentHeaders = bodyResult.$2;

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

    // Headers Handling
    final rawHeaders = await Future.wait(
      _handleHeaders(node.config.headers, inheritedHeaders).map((h) async {
        return [
          await resolveVariables(h[0], resolver, context: context),
          await resolveVariables(h[1], resolver, context: context),
        ];
      }).toList(),
    );

    // Merge generated content headers (e.g. multipart boundary)
    final headers = List<List<String>>.from(rawHeaders);
    if (contentHeaders != null) {
      for (final ch in contentHeaders) {
        // Remove existing header with same key (case-insensitive)
        headers.removeWhere((h) => h[0].toLowerCase() == ch[0].toLowerCase());
        headers.add(ch);
      }
    }

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

  Future<(dynamic, List<List<String>>?)> _resolveBody(
    dynamic body,
    String? bodyType,
    LazyVariableResolver resolver,
    BuildContext context,
  ) async {
    if (body == null) return (null, null);

    // If bodyType is 'No Body', return null
    if (bodyType == BodyType.noBody || bodyType == null) {
      return (null, null);
    }

    // Attempt to parse JSON structure
    Map<String, dynamic>? jsonBody;
    if (body is String && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          jsonBody = decoded;
        }
      } catch (_) {
        // Not JSON, treat as legacy raw text if applicable
      }
    } else if (body is Map<String, dynamic>) {
      jsonBody = body;
    }

    // If we successfully parsed the storage JSON, we MUST use its keys.
    // If keys are missing (e.g. switching types without typing), treat as empty.

    // 1. Binary File
    if (bodyType == BodyType.binaryFile) {
      if (jsonBody != null) {
        final path = jsonBody['file'] as String?;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            return (bytes, null);
          }
        }
        return (null, null);
      }
      return (null, null);
    }

    // 2. Form Data (Multipart)
    if (bodyType == BodyType.formMultipart) {
      final List<dynamic>? formList = jsonBody?['form'] as List?;
      final items =
          formList?.map((e) => FormDataItem.fromMap(e)).toList() ?? [];

      if (items.isEmpty) return (null, null);

      final formMap = <String, dynamic>{};
      for (final item in items) {
        if (!item.isEnabled) continue;
        final key = await resolveVariables(
          item.key,
          resolver,
          context: context,
        );

        if (item.type == 'text') {
          final val = await resolveVariables(
            item.value,
            resolver,
            context: context,
          );
          formMap[key] = val;
        } else if (item.type == 'file') {
          if (item.filePath != null && item.filePath!.isNotEmpty) {
            final file = File(item.filePath!);
            if (await file.exists()) {
              final fileName = item.fileName?.isNotEmpty == true
                  ? item.fileName
                  : item.filePath!.split(Platform.pathSeparator).last;

              formMap[key] = await MultipartFile.fromFile(
                item.filePath!,
                filename: fileName,
                contentType:
                    item.contentType != null && item.contentType!.isNotEmpty
                    ? DioMediaType.parse(item.contentType!)
                    : null,
              );
            }
          }
        }
      }

      if (formMap.isEmpty) return (null, null);

      final formData = FormData.fromMap(formMap);
      // Read bytes from stream. We use Dio's FormData to easily construct the multipart structure.
      final bytes = <int>[];
      await for (final chunk in formData.finalize()) {
        bytes.addAll(chunk);
      }

      final headers = [
        ['Content-Type', 'multipart/form-data; boundary=${formData.boundary}'],
        ['Content-Length', bytes.length.toString()],
      ];
      return (bytes, headers);
    }

    // 3. Form Data (URL Encoded)
    if (bodyType == BodyType.formUrlEncoded) {
      final List<dynamic>? formList = jsonBody?['form'] as List?;
      final items =
          formList?.map((e) => FormDataItem.fromMap(e)).toList() ?? [];

      if (items.isEmpty) return (null, null);

      final parts = <String>[];
      for (final item in items) {
        if (!item.isEnabled) continue;
        final key = await resolveVariables(
          item.key,
          resolver,
          context: context,
        );
        final val = await resolveVariables(
          item.value,
          resolver,
          context: context,
        );

        parts.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(val)}',
        );
      }

      if (parts.isEmpty) return (null, null);

      final str = parts.join('&');
      return (
        str,
        [
          ['Content-Type', 'application/x-www-form-urlencoded'],
        ],
      );
    }

    // 4. Raw Text (JSON/XML/Text)
    // If we have valid storage JSON, take 'text' (or empty if missing)
    if (jsonBody != null) {
      final text = jsonBody['text'] as String?;
      final resolved = await resolveVariables(
        text ?? '',
        resolver,
        context: context,
      );
      return (resolved, null);
    }

    // Fallback: If body was NOT valid JSON storage map, assume it's legacy raw text
    if (body is String) {
      final resolved = await resolveVariables(body, resolver, context: context);
      return (resolved, null);
    }

    return (null, null);
  }

  Future<(dynamic, List<List<String>>?)> _resolveGraphqlBody(
    dynamic body,
    LazyVariableResolver resolver,
    BuildContext context,
  ) async {
    String query = '';
    String variables = '';

    if (body is String && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          query = decoded['query'] ?? '';
          variables = decoded['variables'] ?? '';
        } else {
          query = body;
        }
      } catch (_) {
        query = body;
      }
    } else if (body is Map<String, dynamic>) {
      query = body['query'] ?? '';
      variables = body['variables'] ?? '';
    }

    final resolvedQuery = await resolveVariables(
      query,
      resolver,
      context: context,
    );

    // Resolve Variables (JSON)
    Map<String, dynamic> resolvedVarsMap = {};
    if (variables.isNotEmpty) {
      final resolvedVariablesStr = await resolveVariables(
        variables,
        resolver,
        context: context,
      );
      try {
        final varsJson = jsonDecode(resolvedVariablesStr);
        if (varsJson is Map<String, dynamic>) {
          resolvedVarsMap = varsJson;
        }
      } catch (e) {
        debugPrint("Error parsing GraphQL variables: $e");
      }
    }

    return (
      {'query': resolvedQuery, 'variables': resolvedVarsMap},
      [
        ['Content-Type', 'application/json'],
      ],
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
  List<KeyValueItem> collectInheritedHeaders(Node node) {
    final result = <KeyValueItem>[];
    Node? ptr = _parentOf(node);
    while (ptr != null) {
      result.insertAll(0, ptr.config.headers.where((h) => h.isEnabled));
      ptr = _parentOf(ptr);
    }
    return result;
  }

  (AuthData, Node?) resolveAuth(Node node) {
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

  Map<String, VariableValue> mergeVariables(Node? node) {
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

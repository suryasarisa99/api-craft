import 'package:api_craft/http/header_utils.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestResolver {
  final Ref ref;
  late final RequestHydrator _hydrator = RequestHydrator(ref);

  RequestResolver(this.ref);

  FolderNode? _parentOf(Node node) {
    return ref.read(fileTreeProvider).nodeMap[node.parentId] as FolderNode?;
  }

  /// ---------- UI RESOLUTION ----------
  Future<UiRequestContext> resolveForUi(String requestId) async {
    final node = ref.read(
      fileTreeProvider.select((t) => t.nodeMap[requestId]!),
    );

    await _hydrator.hydrateNode(node);
    await _hydrator.hydrateAncestors(node);

    final inheritedHeaders = _collectInheritedHeaders(node);
    final authResult = _resolveAuth(node);
    final vars = _mergeVariables(node);

    return UiRequestContext(
      node: node,
      inheritedHeaders: inheritedHeaders,
      effectiveAuth: authResult.$1,
      authSource: authResult.$2,
      allVariables: vars,
    );
  }

  /// ---------- EXECUTION RESOLUTION ----------
  Future<ResolvedRequestContext> resolveForExecution(String requestId) async {
    final node =
        ref.read(fileTreeProvider.select((t) => t.nodeMap[requestId]!))
            as RequestNode;

    await _hydrator.hydrateNode(node);
    await _hydrator.hydrateAncestors(node);

    final inheritedHeaders = _collectInheritedHeaders(node);
    final auth = _resolveAuth(node).$1;
    final mergedVars = _mergeVariables(node);
    final resolvedVars = _resolveVariableValues(mergedVars, 50);

    final resolvedUrl = _resolveVariables(node.url, resolvedVars);
    final uri = Uri.parse(resolvedUrl);

    final queryParams =
        cleanKeyValueItems(
          node.config.queryParameters,
          removeEmptyKeys: false,
        ).map((p) {
          return [
            _resolveVariables(p[0], resolvedVars),
            _resolveVariables(p[1], resolvedVars),
          ];
        }).toList();
    final fullUri = _handleUri(uri, queryParams);

    final headers = _handleHeaders(node.config.headers, inheritedHeaders).map((
      h,
    ) {
      return [
        _resolveVariables(h[0], resolvedVars),
        _resolveVariables(h[1], resolvedVars),
      ];
    }).toList();

    return ResolvedRequestContext(
      request: node,
      uri: fullUri,
      headers: headers,
      auth: auth,
      variables: resolvedVars,
    );
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

  Map<String, VariableValue> _mergeVariables(Node node) {
    final result = <String, VariableValue>{};
    final chain = <FolderNode>[];

    var ptr = _parentOf(node);
    while (ptr != null) {
      chain.insert(0, ptr);
      ptr = _parentOf(ptr);
    }

    for (final folder in chain) {
      for (final v in folder.config.variables) {
        if (v.isEnabled) {
          result[v.key] = VariableValue(folder.id, v.value);
        }
      }
    }

    return result;
  }

  Map<String, VariableValue> _resolveVariableValues(
    Map<String, VariableValue> vars,
    int depth,
  ) {
    var current = vars;

    for (int i = 0; i < depth; i++) {
      final next = <String, VariableValue>{};
      bool changed = false;

      for (final e in current.entries) {
        final value = e.value.value;
        if (value is String) {
          final resolved = _resolveVariables(value, current);
          if (resolved != value) changed = true;
          next[e.key] = VariableValue(e.value.sourceId, resolved);
        } else {
          next[e.key] = e.value;
        }
      }

      if (!changed) return next;
      current = next;
    }
    return current;
  }

  final _variableRegExp = RegExp(r'{{\s*([a-zA-Z0-9_-]+)\s*}}');
  // final _variableRegExp = RegExp(r'{{\s*([^{}\s]+)\s*}}');
  String _resolveVariables(String text, Map<String, VariableValue> values) {
    // Match all {{variable}} patterns
    return text.replaceAllMapped(_variableRegExp, (match) {
      final key = match.group(1);
      if (key != null && values.containsKey(key)) {
        return values[key]!.value; // Replace with value
      }
      return match.group(0)!; // leave as is if no value found
    });
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

  Uri _handleUri2(Uri url, List<List<String>> params) {
    final buffer = StringBuffer();

    // 1️⃣ Existing query from URL (as-is, but normalized)
    if (url.hasQuery) {
      final existing = url.query.split('&').where((e) => e.isNotEmpty);
      for (final q in existing) {
        if (buffer.isNotEmpty) buffer.write('&');
        buffer.write(q);
      }
    }

    // 2️⃣ Append KV params (duplicates allowed)
    for (final p in params) {
      if (p.length != 2) continue;

      final key = p[0];
      if (key.isEmpty) continue;

      final value = p[1];

      if (buffer.isNotEmpty) buffer.write('&');
      buffer.write(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
      );
    }

    // 3️⃣ Replace query
    return buffer.isEmpty ? url : url.replace(query: buffer.toString());
  }
}

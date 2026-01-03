import 'dart:convert';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:api_craft/core/network/raw/raw_http_req.dart';

class GraphqlTab extends ConsumerStatefulWidget {
  final String id;
  const GraphqlTab({super.key, required this.id});

  @override
  ConsumerState<GraphqlTab> createState() => _GraphqlTabState();
}

class _GraphqlTabState extends ConsumerState<GraphqlTab> {
  final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(data: 'query'), // Query
      Area(data: 'variables', size: 100), // Variables
    ],
  );

  String _query = '';
  String _variables = '';
  bool _initialized = false;

  // Introspection Query
  static const String introspectionQuery = """
    query IntrospectionQuery {
      __schema {
        queryType { name }
        mutationType { name }
        subscriptionType { name }
        types {
          ...FullType
        }
        directives {
          name
          description
          locations
          args {
            ...InputValue
          }
        }
      }
    }
    fragment FullType on __Type {
      kind
      name
      description
      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }
    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue
    }
    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
  """;

  @override
  void initState() {
    super.initState();
  }

  void _initData(Map<String, dynamic> bodyData) {
    if (_initialized) return;
    _initialized = true;

    _query = bodyData['query'] as String? ?? '';
    _variables = bodyData['variables'] as String? ?? '';

    // Legacy fallback: check 'text' if query is empty?
    if (_query.isEmpty) {
      final text = bodyData['text'] as String?;
      if (text != null && text.isNotEmpty) {
        try {
          final json = jsonDecode(text);
          if (json is Map) {
            _query = json['query'] ?? '';
            _variables = json['variables'] ?? '';
          } else {
            _query = text;
          }
        } catch (_) {
          _query = text;
        }
      }
    }
  }

  void _update() {
    final map = {'query': _query, 'variables': _variables};
    ref.read(reqComposeProvider(widget.id).notifier).updateBodyMap(map);
  }

  Future<void> _fetchSchema() async {
    try {
      final resolver = ref.read(requestResolverProvider);
      final reqContext = await resolver.resolveForExecution(
        widget.id,
        context: context,
      );

      // Perform Introspection
      // We use the same headers/auth/url but replace body with introspection query
      final httpResponse = await sendRawHttp(
        method: 'POST',
        url: reqContext.uri,
        headers: [
          ...reqContext.headers,
          ['Content-Type', 'application/json'],
        ],
        body: jsonEncode({'query': introspectionQuery}),
        requestId: 'introspection-${widget.id}',
        useProxy: false,
      );

      if (httpResponse.statusCode == 200) {
        // Validation/Success
        debugPrint(
          "Schema fetched successfully: ${httpResponse.body.length} chars",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Schema Fetched Successfully (${httpResponse.durationMs}ms)",
            ),
          ),
        );
        // TODO: Save schema to a file or provider for completion support
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Schema fetch failed: ${httpResponse.statusCode}"),
          ),
        );
      }
    } catch (e) {
      debugPrint("Schema fetch error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching schema: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestState = ref.watch(reqComposeProvider(widget.id));
    final bodyData = requestState.bodyData;

    // If not initialized, parse the text
    if (!_initialized) {
      _initData(bodyData);
    } else {
      // Check if external update (e.g. undo/redo, or file reload) happened
      // Simple check: if jsonEncode(current) != text, handle?
      // For now, assume one-way sync mainly or rely on _initData only once?
      // No, if we switch tabs and come back, initState runs again.
      // If we stay in tab and data changes externally (e.g. sync), we might get desync.
      // But let's keep it simple.
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Text(
                "GraphQL",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text("Fetch Schema"),
                onPressed: _fetchSchema,
              ),
            ],
          ),
        ),
        Expanded(
          child: MultiSplitView(
            controller: _controller,
            axis: Axis.vertical,
            builder: (context, area) {
              if (area.data == 'query') {
                return _buildQueryEditor();
              } else {
                return _buildVariablesEditor();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQueryEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Text(
            "Query",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Expanded(
          child: CFCodeEditor(
            key: const ValueKey('graphql-query'),
            text: _query,
            language: 'graphql',
            onChanged: (val) {
              _query = val;
              _update();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVariablesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Text(
            "Variables",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Expanded(
          child: CFCodeEditor(
            key: const ValueKey('graphql-vars'),
            text: _variables,
            language: 'json',
            onChanged: (val) {
              _variables = val;
              _update();
            },
          ),
        ),
      ],
    );
  }
}

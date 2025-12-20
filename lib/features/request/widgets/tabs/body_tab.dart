import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:api_craft/core/models/models.dart';

class BodyTab extends ConsumerStatefulWidget {
  final String id;
  const BodyTab({super.key, required this.id});

  @override
  ConsumerState<BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends ConsumerState<BodyTab> {
  late CodeController _controller;

  @override
  void initState() {
    super.initState();
    final body = ref.read(reqComposeProvider(widget.id)).body;
    _controller = CodeController(
      text: body,
      language: _getLanguage(ref.read(reqComposeProvider(widget.id)).node),
    );

    _controller.addListener(() {
      if (ref.read(reqComposeProvider(widget.id)).isLoading) return;
      final newBody = _controller.text;
      ref.read(reqComposeProvider(widget.id).notifier).updateBody(newBody);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for changes from outside (e.g. undo/redo or node switch)
    ref.listen(reqComposeProvider(widget.id).select((d) => d.body), (
      prev,
      next,
    ) {
      if (next != null && next != _controller.text) {
        _controller.text = next;
      }
    });

    ref.listen(reqComposeProvider(widget.id).select((d) => d.node), (
      prev,
      next,
    ) {
      final prevType = (prev as RequestNode).config.bodyType;
      final nextType = (next as RequestNode).config.bodyType;
      if (prevType != nextType) {
        setState(() {
          _controller.language = _getLanguage(next);
        });
      }
    });

    final styles = Map<String, TextStyle>.from(atomOneDarkTheme);
    styles['root'] = styles['root']!.copyWith(
      backgroundColor: Colors.transparent,
    );

    return CodeTheme(
      data: CodeThemeData(styles: styles),
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
        child: CodeField(
          controller: _controller,
          readOnly: ref.watch(
            reqComposeProvider(widget.id).select((d) => d.isLoading),
          ),
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 16),
          expands: true,
          decoration: const BoxDecoration(),
        ),
      ),
    );
  }

  dynamic _getLanguage(Node node) {
    if (node is RequestNode) {
      final type = node.config.bodyType;
      if (type == 'json') return json;
      if (type == 'xml') return xml;
      if (type == 'html') return xml;
      if (type == 'javascript') return javascript;
    }
    return null;
  }
}

import 'dart:convert';
import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:api_craft/features/response/response_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/javascript.dart';

class ResponseBodyTab extends StatefulWidget {
  final RawHttpResponse response;
  final BodyViewMode mode;

  const ResponseBodyTab({
    super.key,
    required this.response,
    required this.mode,
  });

  @override
  State<ResponseBodyTab> createState() => _ResponseBodyTabState();
}

class _ResponseBodyTabState extends State<ResponseBodyTab> {
  late CodeController _controller;

  @override
  void initState() {
    super.initState();
    _updateController();
  }

  @override
  void didUpdateWidget(ResponseBodyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.response != widget.response) {
      _updateController();
    }
  }

  void _updateController() {
    String text = widget.response.body;
    if (widget.mode == BodyViewMode.pretty) {
      text = _prettyPrint(text);
    }

    _controller = CodeController(
      text: text,
      language: _detectLanguage(),
      readOnly: true,
    );
  }

  String _prettyPrint(String text) {
    try {
      final dynamic jsonObj = jsonDecode(text);
      return const JsonEncoder.withIndent('  ').convert(jsonObj);
    } catch (_) {
      return text;
    }
  }

  dynamic _detectLanguage() {
    final bodyType = widget.response.bodyType?.toLowerCase() ?? '';
    if (bodyType.contains('json')) return json;
    if (bodyType.contains('xml') || bodyType.contains('html')) return xml;
    if (bodyType.contains('javascript')) return javascript;
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styles = Map<String, TextStyle>.from(atomOneDarkTheme);
    styles['root'] = styles['root']!.copyWith(
      backgroundColor: Colors.transparent,
    );

    return CodeTheme(
      data: CodeThemeData(styles: styles), // Basic styles
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
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          expands: true,
          decoration: const BoxDecoration(),
        ),
      ),
    );
  }
}

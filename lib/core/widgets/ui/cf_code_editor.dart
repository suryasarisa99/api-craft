import 'package:flutter/material.dart';
import 'package:code_forge/code_forge.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

class CFCodeEditor extends StatefulWidget {
  final String text;
  final String? language;
  final void Function(String)? onChanged;
  final bool readOnly;
  final double fontSize;

  const CFCodeEditor({
    super.key,
    required this.text,
    this.language,
    this.onChanged,
    this.readOnly = false,
    this.fontSize = 16,
  });

  @override
  State<CFCodeEditor> createState() => _CFCodeEditorState();
}

class _CFCodeEditorState extends State<CFCodeEditor> {
  late CodeForgeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeForgeController();
    _controller.text = widget.text;
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (widget.onChanged != null && _controller.text != widget.text) {
      widget.onChanged!(_controller.text);
    }
  }

  @override
  void didUpdateWidget(CFCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Mode _getLanguage(String? lang) {
    debugPrint('lang: $lang');
    if (lang == null) return langDart;
    final l = lang.toLowerCase();
    if (l.contains('json')) return langJson;
    if (l.contains('xml') || l.contains('html')) return langXml;
    if (l.contains('javascript') || l.contains('js')) return langJavascript;
    return langDart;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Map<String, TextStyle>.from(atomOneDarkTheme);
    theme['root'] = theme['root']!.copyWith(
      backgroundColor: Colors.transparent,
    );
    return CodeForge(
      controller: _controller,
      language: _getLanguage(widget.language),
      editorTheme: theme,

      readOnly: widget.readOnly,
      enableGutter: true,
      enableFolding: true,
      textStyle: TextStyle(fontFamily: 'monospace', fontSize: widget.fontSize),
    );
  }
}

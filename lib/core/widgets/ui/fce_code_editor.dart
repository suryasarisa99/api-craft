import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/javascript.dart';

class FCECodeEditor extends StatefulWidget {
  final String text;
  final String? language;
  final void Function(String)? onChanged;
  final bool readOnly;
  final double fontSize;

  const FCECodeEditor({
    super.key,
    required this.text,
    this.language,
    this.onChanged,
    this.readOnly = false,
    this.fontSize = 16,
  });

  @override
  State<FCECodeEditor> createState() => _FCECodeEditorState();
}

class _FCECodeEditorState extends State<FCECodeEditor> {
  late CodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: widget.text,
      language: _getLanguage(widget.language),
    );

    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (widget.onChanged != null && _controller.text != widget.text) {
      widget.onChanged!(_controller.text);
    }
  }

  @override
  void didUpdateWidget(FCECodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
    if (widget.language != oldWidget.language) {
      setState(() {
        _controller.language = _getLanguage(widget.language);
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  dynamic _getLanguage(String? lang) {
    if (lang == null) return null;
    final l = lang.toLowerCase();
    if (l.contains('json')) return json;
    if (l.contains('xml') || l.contains('html')) return xml;
    if (l.contains('javascript') || l.contains('js')) return javascript;
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          readOnly: widget.readOnly,
          textStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: widget.fontSize,
          ),
          expands: true,
          decoration: const BoxDecoration(),
        ),
      ),
    );
  }
}

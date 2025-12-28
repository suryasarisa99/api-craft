import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/core/widgets/ui/finder.dart';
import 'package:api_craft/core/widgets/ui/key_value_lang.dart';
import 'package:api_craft/main.dart';
import 'package:flutter/material.dart';
import 'package:code_forge/code_forge.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/javascript.dart';
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
  final debouncer = DebouncerFlush(Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _controller = CodeForgeController();
    _controller.text = widget.text;
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    debouncer.run(() {
      if (widget.onChanged != null && _controller.text != widget.text) {
        widget.onChanged!(_controller.text);
      }
    });
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
    debouncer.flush();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Mode? _getLanguage(String? lang) {
    if (lang == null) return null;
    final l = lang.toLowerCase();
    if (l == "form-urlencoded") return langKeyValue;
    if (l.contains('json')) return langJson;
    if (l.contains('xml') || l.contains('html')) return langXml;
    if (l.contains('javascript') || l.contains('js')) return langJavascript;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Map<String, TextStyle>.from(atomOneDarkTheme);
    theme['root'] = theme['root']!.copyWith(
      backgroundColor: const Color.fromARGB(255, 33, 33, 33),
    );
    final cs = Theme.of(context).colorScheme;
    return CodeForge(
      controller: _controller,
      language: _getLanguage(widget.language),
      editorTheme: theme,
      readOnly: widget.readOnly,
      enableGutter: true,
      enableFolding: true,
      finderBuilder: (_, controller) => FindPanelView(controller: controller),
      hoverDetailsStyle: HoverDetailsStyle(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: Colors.black,
        focusColor: Colors.black,
        hoverColor: Colors.black,
        splashColor: Colors.black,
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
      selectionStyle: CodeSelectionStyle(selectionColor: Colors.blueGrey),
      // suggestionStyle: SuggestionStyle(
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(4),
      //     side: BorderSide(color: const Color.fromARGB(255, 108, 108, 108)),
      //   ),
      //   backgroundColor: Colors.red,
      //   focusColor: Colors.black,
      //   hoverColor: Colors.green,
      //   splashColor: Colors.black,
      //   textStyle: TextStyle(color: Colors.white, fontSize: 12),
      // ),
      matchHighlightStyle: MatchHighlightStyle(
        currentMatchStyle: TextStyle(
          backgroundColor: Color.fromARGB(255, 131, 79, 132),
        ),
        otherMatchStyle: TextStyle(
          backgroundColor: Color.fromARGB(
            255,
            143,
            86,
            145,
          ).withValues(alpha: 0.4),
        ),
      ),
      lineWrap: true,
      textStyle: TextStyle(fontFamily: 'monospace', fontSize: widget.fontSize),
    );
  }
}

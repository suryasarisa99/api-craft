import 'dart:convert';
import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:api_craft/features/response/response_tab.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';

class ResponseBodyTab extends StatelessWidget {
  final RawHttpResponse response;
  final BodyViewMode mode;

  const ResponseBodyTab({
    super.key,
    required this.response,
    required this.mode,
  });

  String _prettyPrint(String text) {
    try {
      final dynamic jsonObj = jsonDecode(text);
      return const JsonEncoder.withIndent('  ').convert(jsonObj);
    } catch (_) {
      return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    String text = response.body;
    if (mode == BodyViewMode.pretty) {
      text = _prettyPrint(text);
    }

    return CFCodeEditor(
      key: ValueKey(response.bodyType),
      text: text,
      language: response.bodyType,
      readOnly: true,
      fontSize: 14,
    );
  }
}

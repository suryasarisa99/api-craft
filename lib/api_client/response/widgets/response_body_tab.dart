import 'dart:convert';
import 'dart:typed_data';
import 'package:api_craft/api_client/response/models/response_history.dart';
import 'package:api_craft/api_client/response/response_tab.dart';
import 'package:api_craft/api_client/response/widgets/json_viewer.dart';
import 'package:api_craft/api_client/response/widgets/image_viewer.dart';
import 'package:api_craft/api_client/response/widgets/hex_viewer.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/shared/ui/cf_code_editor.dart';
import 'package:xml/xml.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ResponseBodyView extends StatelessWidget {
  final Uint8List body;
  final List<List<String>>? headers;
  final BodyViewMode mode;
  final String? bodyType;
  final String id;

  //
  String? contentType;
  String? _text;
  String? _prettyText;
  String? _json;
  String? _xml;

  String get text {
    if (_text != null) {
      return _text!;
    }
    return utf8.decode(body, allowMalformed: true);
  }

  String get prettyText {
    if (_prettyText != null) {
      return _prettyText!;
    }
    return _prettyPrint();
  }

  dynamic get json {
    if (_json != null) {
      return _json!;
    }
    return jsonDecode(text);
  }

  String get xml {
    if (_xml != null) {
      return _xml!;
    }
    return text;
  }

  ResponseBodyView({
    super.key,
    required this.body,
    this.headers,
    required this.mode,
    required this.id,
    this.bodyType,
    String? contentType,
  }) {
    if (contentType != null) {
      this.contentType = contentType;
    } else {
      for (final header in headers ?? []) {
        if (header[0].toLowerCase() == 'content-type') {
          this.contentType = header[1].toLowerCase();
          break;
        }
      }
    }
  }

  String _prettyPrint() {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      debugPrint("Failed to parse JSON");
    }

    //xml
    try {
      //try xml pretty print
      final parser = XmlDocument.parse(text);
      return parser.toXmlString(pretty: true, indent: '  ');
    } catch (_) {
      debugPrint("Failed to parse XML");
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("rebuild:::response-body");
    if (mode == BodyViewMode.hex) {
      return HexViewer(bytes: body);
    }
    if (mode == BodyViewMode.json) {
      try {
        return Expanded(child: JsonPreviewer(code: json));
      } catch (e) {
        return Center(
          child: Text(
            "Invalid JSON",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      }
    }

    final contentType = this.contentType;

    if (contentType != null) {
      debugPrint("contentType: $contentType");
      if (contentType.contains('image/svg')) {
        return InteractiveViewer(
          maxScale: 100,
          // alignment: Alignment.center,
          child: Center(child: SvgPicture.memory(body)),
        );
      } else if (contentType.contains('image/')) {
        return ImageViewer(imageBytes: body);
      }
    }

    if (mode == BodyViewMode.pretty) {
      return CFCodeEditor(
        key: ValueKey(id),
        text: prettyText,
        language: bodyType,
        readOnly: true,
        fontSize: 14,
      );
    }

    return CFCodeEditor(
      key: ValueKey(id),
      text: text,
      language: bodyType,
      readOnly: true,
      fontSize: 14,
    );
  }
}

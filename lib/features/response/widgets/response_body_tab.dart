import 'dart:convert';
import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:api_craft/features/response/response_tab.dart';
import 'package:api_craft/features/response/widgets/json_viewer.dart';
import 'package:api_craft/features/response/widgets/image_viewer.dart';
import 'package:api_craft/features/response/widgets/hex_viewer.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';
import 'package:xml/xml.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    } catch (_) {}

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

  String? get _contentType {
    for (final header in response.headers) {
      if (header[0].toLowerCase() == 'content-type') {
        return header[1].toLowerCase();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (mode == BodyViewMode.hex) {
      return HexViewer(bytes: response.bodyBytes);
    }
    if (mode == BodyViewMode.json) {
      try {
        final jsonObj = jsonDecode(response.body);
        if (jsonObj is Map<String, dynamic>) {
          return JsonViewer(jsonObj: jsonObj);
        } else if (jsonObj is List) {
          // Wrap list in a map to display it, or use JsonViewer for lists if supported
          // flutter_json_view supports maps/lists differently usually, but let's check basic usage
          // JsonView.map is used in JsonViewer. Let's create a JsonList wrapper or just show as map
          return JsonViewer(jsonObj: {'root': jsonObj});
        }
      } catch (e) {
        return Center(
          child: Text(
            "Invalid JSON",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      }
    }

    final contentType = _contentType;

    if (contentType != null) {
      debugPrint("contentType: $contentType");
      if (contentType.contains('image/svg')) {
        return InteractiveViewer(
          maxScale: 100,
          // alignment: Alignment.center,
          child: Center(child: SvgPicture.memory(response.bodyBytes)),
        );
      } else if (contentType.contains('image/')) {
        return ImageViewer(imageBytes: response.bodyBytes);
      }
    }

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

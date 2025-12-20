import 'package:api_craft/features/template-functions/functions/template_common_args.dart';
import 'package:api_craft/features/template-functions/models/enums.dart';
import 'package:api_craft/features/template-functions/models/form_input.dart';
import 'package:api_craft/features/template-functions/models/template_functions.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';

final xmlPathFn = TemplateFunction(
  name: 'xml.path',
  description: 'Extract text using a xml path expression',
  args: [
    FormInputText(
      name: 'input',
      label: 'Input',
      placeholder: '<root><foo>bar</foo></root>',
      defaultValue: '<root><foo>bar</foo></root>',
    ),
    returnFormatHstak,
    FormInputCheckbox(
      name: 'formatted',
      label: 'Pretty Print',
      description: 'Format the output as XML',
    ),
    FormInputText(name: 'query', label: 'Query', placeholder: '/root/foo'),
  ],
  onRender: (ref, ctx, args) async {
    try {
      final query = args.values['query'];
      final input = args.values['input'];
      if (query == null || input == null) return null;
      debugPrint(
        "i: $input, q: $query, r: ${args.values['result']}, j: ${args.values['join']}",
      );
      return filterXmlPath(
        input,
        query,
        args.values['result'],
        join: args.values['join'],
        // formatted: args.values['formatted'],
      );
    } catch (e) {
      debugPrint("err: $e ");
      return null;
    }
  },
);
String? filterXmlPath(
  String body,
  String path,
  String returnFormat, {
  String join = ', ',
}) {
  debugPrint("b: $body, p: $path, r: $returnFormat, j: $join");
  final document = XmlDocument.parse(body);

  final nodes = document.xpath(path);
  debugPrint("nodes len: ${nodes.length}");

  if (nodes.isEmpty) return null;

  if (returnFormat == Return.first.name) {
    debugPrint("first: ${nodes.first.value}");
    return _nodeToString(nodes.first);
  } else if (returnFormat == Return.last.name) {
    debugPrint("last: ${nodes.last.value}");
    return _nodeToString(nodes.last);
  } else {
    debugPrint("join: ${nodes.map(_nodeToString).join(join)}");
    return nodes.map(_nodeToString).join(join);
  }
}

String? _nodeToString(XmlNode node) {
  if (node is XmlAttribute) return node.value;
  return node.value;
}

// String? _nodeToString(XmlNode node) {
//   if (node is XmlAttribute) return node.value;
//   if (node is XmlText) return node.text;
//   if (node is XmlElement) return node.text; // IMPORTANT
//   return null;
// }

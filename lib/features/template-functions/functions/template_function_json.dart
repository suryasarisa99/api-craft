import 'dart:convert';

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/template-functions/functions/template_common_args.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';

final jsonPathFn = TemplateFunction(
  name: "json.path",
  description: "Extract text using a json path expression",
  args: [
    FormInputText(
      name: "input",
      label: "Input",
      placeholder: '{ "foo": "bar" }',
    ),
    returnFormatHstak,
    FormInputCheckbox(
      name: 'formatted',
      label: 'Pretty Print',
      description: 'Format the output as JSON',
    ),
    FormInputText(name: 'query', label: 'Query', placeholder: '\$..foo'),
  ],
  onRender: (ref, ctx, args) async {
    try {
      return filterJsonPath(
        args.values['input'],
        args.values['query'],
        args.values['result'] ?? Return.first.name,
        join: args.values['join'] ?? ', ',
      );
    } catch (e) {
      debugPrint("err: $e ");
      return null;
    }
  },
);

String? filterJsonPath(
  String body,
  String path,
  String returnFormat, {
  String join = ', ',
}) {
  final parsed = jsonDecode(body);
  debugPrint("Parsed body: $parsed");
  var items = JsonPath(path).read(parsed);
  if (returnFormat == Return.first.name) {
    if (items.isNotEmpty) {
      return objToString(items.first.value);
    }
    return null;
  } else if (returnFormat == Return.last.name) {
    if (items.isNotEmpty) {
      return objToString(items.last.value);
    }
    return null;
  } else {
    final values = items.map((e) => objToString(e.value)).toList();
    return values.join(join);
  }
}

String objToString(dynamic obj) {
  if (obj == null) return 'null';
  if (obj is String) return obj;
  if (obj is num || obj is bool) return obj.toString();
  try {
    return jsonEncode(obj);
  } catch (e) {
    return obj.toString();
  }
}

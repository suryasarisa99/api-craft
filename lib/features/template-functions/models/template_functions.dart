import 'package:api_craft/core/models/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TemplateFunction {
  // response.body
  final String name;
  final String description;
  final String previewType;
  final List<FormInput> args;
  final Future<dynamic> Function(
    Ref ref,
    BuildContext context,
    CallTemplateFunctionArgs args,
  )
  onRender;
  // Todo : need to complete other parameters
  // previewArgs,aliases

  const TemplateFunction({
    required this.name,
    required this.description,
    required this.args,
    required this.onRender,
    this.previewType = "auto",
  });
}

class CallTemplateFunctionArgs {
  Map<String, dynamic> values;
  Purpose purpose;

  CallTemplateFunctionArgs({required this.values, required this.purpose});
}

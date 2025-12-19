import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/template-functions/models/form_input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TemplateFunction {
  // response.body
  final String name;
  final String description;
  final List<FormInput> args;
  final Future<dynamic> Function(Ref ctx, CallTemplateFunctionArgs args)
  onRender;
  // Todo : need to complete other parameters
  // previewArgs,aliases

  const TemplateFunction({
    required this.name,
    required this.description,
    required this.args,
    required this.onRender,
  });
}

class CallTemplateFunctionArgs {
  Map<String, dynamic> values;
  Purpose purpose;

  CallTemplateFunctionArgs({required this.values, required this.purpose});
}

abstract class TemplatePlaceholder {
  String name;
  final int start; // index of {{
  final int end; // index AFTER }}
  TemplatePlaceholder({
    required this.name,
    required this.start,
    required this.end,
  });
}

class TemplateVariablePlaceholder extends TemplatePlaceholder {
  TemplateVariablePlaceholder({
    required super.name,
    required super.start,
    required super.end,
  });
}

class TemplateFnPlaceholder extends TemplatePlaceholder {
  final Map<String, dynamic>? args; // null = variable

  TemplateFnPlaceholder({
    required super.name,
    required this.args,
    required super.start,
    required super.end,
  });

  bool get isFunction => args != null;

  //copy with new args
  TemplateFnPlaceholder copyWithArgs(Map<String, dynamic> newArgs) {
    return TemplateFnPlaceholder(
      name: name,
      args: newArgs,
      start: start,
      end: end,
    );
  }
}

import 'package:api_craft/models/models.dart';

class TemplateFunction {
  // response.body
  final String name;
  final String description;
  final List<FormInput> args;
  final Future<dynamic> Function(WContext ctx, CallTemplateFunctionArgs args)
  onRender;
  // Todo : need to complete other parameters

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

import 'package:api_craft/features/template-functions/functions/template_function_cookie.dart';
import 'package:api_craft/features/template-functions/functions/template_function_ctx.dart';
import 'package:api_craft/features/template-functions/functions/template_function_json.dart';
import 'package:api_craft/features/template-functions/functions/template_function_prompt.dart';
import 'package:api_craft/features/template-functions/functions/template_function_regex.dart';
import 'package:api_craft/features/template-functions/functions/template_function_response.dart';
import 'package:api_craft/features/template-functions/functions/template_function_xml.dart';
import 'package:api_craft/features/template-functions/functions/secure_fn.dart';
import 'package:api_craft/features/template-functions/models/template_functions.dart';

final templates = [
  // response
  responseBodyPath,
  responseBodyRaw,
  responseHeader,

  // regex
  regexMatchFn,
  regexReplaceFn,

  //other
  promptFn,
  cookieValueFn,
  jsonPathFn,
  xmlPathFn,
  secureFn,

  // ctx
  ctxWorkspaceIdFn,
  ctxWorkspaceNameFn,
];

Map<String, TemplateFunction> get templateFunctionRegistry {
  final Map<String, TemplateFunction> registry = {};
  for (final fn in templates) {
    registry[fn.name] = fn;
  }
  return registry;
}

final Map<String, TemplateFunction> _templateFunctionRegistry =
    templateFunctionRegistry;
TemplateFunction? getTemplateFunctionByName(String name) {
  return _templateFunctionRegistry[name];
}

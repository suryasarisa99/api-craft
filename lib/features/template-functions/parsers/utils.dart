import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/template-functions/functions/template_function_cookie.dart';
import 'package:api_craft/features/template-functions/functions/template_function_ctx.dart';
import 'package:api_craft/features/template-functions/functions/template_function_json.dart';
import 'package:api_craft/features/template-functions/functions/template_function_prompt.dart';
import 'package:api_craft/features/template-functions/functions/template_function_regex.dart';
import 'package:api_craft/features/template-functions/functions/template_function_response.dart';
import 'package:api_craft/features/template-functions/functions/template_function_xml.dart';

Map<String, dynamic> getDefaultTemplateFunctionState(TemplateFunction fn) {
  final Map<String, dynamic> defaultState = {};
  for (final input in fn.args) {
    if (input is FormInputBase) {
      defaultState[input.name] = input.defaultValue;
    } else if (input is FormInputHStack) {
      // hStack inputs have nested inputs
      for (final nestedInput in input.inputs ?? []) {
        if (nestedInput is FormInputBase) {
          defaultState[nestedInput.name] = nestedInput.defaultValue;
        }
      }
    }
  }
  return defaultState;
}

// merges default values and provided state
Map<String, dynamic> getFnState(
  TemplateFunction fn,
  Map<String, dynamic>? providedState,
) {
  final defaultState = getDefaultTemplateFunctionState(fn);
  if (providedState == null) {
    return defaultState;
  }
  final mergedState = Map<String, dynamic>.from(defaultState);
  mergedState.addAll(providedState);
  return mergedState;
}

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

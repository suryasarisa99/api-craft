import 'package:api_craft/features/dynamic-form/form_input.dart';

Map<String, dynamic> getDefaultFormState(List<FormInput> inputs) {
  final Map<String, dynamic> defaultState = {};
  for (final input in inputs) {
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
  List<FormInput> fn,
  Map<String, dynamic>? providedState,
) {
  final defaultState = getDefaultFormState(fn);
  if (providedState == null) {
    return defaultState;
  }
  final mergedState = Map<String, dynamic>.from(defaultState);
  mergedState.addAll(providedState);
  return mergedState;
}

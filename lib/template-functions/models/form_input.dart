import 'dart:async';
import 'dart:ui';

import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef WContext = WidgetRef;
// dynamic?: (ctx, args) => Promise<Partial<FormInputEditor>>;
typedef DynamicFn =
    FutureOr<dynamic> Function(WidgetRef ctx, CallTemplateFunctionArgs args);

abstract class FormInput {
  final ArgumentType type;
  final DynamicFn? dynamicFn;

  FormInput({required this.type, this.dynamicFn});
}

// used by all inputs except  layout types (hStack, accordion)
abstract class FormInputBase extends FormInput {
  final String name;
  final String? label;
  final String? placeholder;
  final dynamic defaultValue;
  final bool? optional;
  final bool? hidden;
  final bool? disabled;
  final bool? hideLabel;
  final String? description;

  FormInputBase({
    required this.name,
    this.label,
    this.placeholder,
    this.defaultValue,
    this.optional,
    this.hidden,
    this.disabled,
    this.hideLabel,
    this.description,

    // super parameters
    required super.type,
    super.dynamicFn,
  });
}

// todo need to define this later

class FormInputText extends FormInputBase {
  final bool password;
  final bool multiline;

  FormInputText({
    this.password = false,
    this.multiline = false,
    // super parameters
    required super.name,
    super.label,
    super.placeholder,
    super.defaultValue,
    super.optional,
    super.hidden,
    super.disabled,
    super.hideLabel,
    super.description,
    super.dynamicFn,
  }) : super(type: ArgumentType.text);
}

class FormInputEditor extends FormInputBase {
  String language; // Todo: create enum for languages
  bool hideGutter;
  bool readOnly;
  List<dynamic>? completionOptions; //Todo define type

  FormInputEditor({
    // this parameters
    this.language = 'json',
    this.hideGutter = false,
    this.readOnly = false,
    this.completionOptions,

    // super parameters
    required super.name,
    super.label,
    super.placeholder,
    super.defaultValue,
    super.optional,
    super.hidden,
    super.disabled,
    super.hideLabel,
    super.description,
    super.dynamicFn,
  }) : super(type: ArgumentType.editor);
}

class FormInputCheckbox extends FormInputBase {
  FormInputCheckbox({
    // super parameters
    required super.name,
    super.label,
    super.placeholder,
    super.defaultValue,
    super.optional,
    super.hidden,
    super.disabled,
    super.hideLabel,
    super.description,
    super.dynamicFn,
  }) : super(type: ArgumentType.checkbox);
}

class FormInputSelect extends FormInputBase {
  final List<FormInputSelectOption> options;

  FormInputSelect({
    required super.name,
    super.label,
    super.placeholder,
    super.defaultValue,
    super.optional,
    super.hidden,
    super.disabled,
    super.hideLabel,
    super.description,
    super.dynamicFn,

    // this parameter
    required this.options,
  }) : super(type: ArgumentType.select);
}

class FormInputSelectOption {
  final String label;
  final String value;

  FormInputSelectOption({required this.label, required this.value});
}

// FILE input
class FormInputFile extends FormInputBase {
  final String title;
  final bool multiple;
  final bool directory;
  final String? defaultPath;
  final List<FileFilter>? filters;

  FormInputFile({
    required this.title,
    this.multiple = false,
    this.directory = false,
    this.defaultPath,
    this.filters,
    required super.name,
    super.label,
    super.placeholder,
    super.defaultValue,
    super.optional,
    super.hidden,
    super.disabled,
    super.hideLabel,
    super.description,
    super.dynamicFn,
  }) : super(type: ArgumentType.file);
}

class FileFilter {
  final String name;
  final List<String> extensions;

  FileFilter({required this.name, required this.extensions});
}

// HTTP REQUEST PICKER input
class FormInputHttpRequest extends FormInputBase {
  FormInputHttpRequest({
    required super.name,
    super.label,
    super.placeholder,
    super.defaultValue,
    super.optional,
    super.hidden,
    super.disabled,
    super.hideLabel,
    super.description,
    super.dynamicFn,
  }) : super(type: ArgumentType.httpRequest);
}

// ACCORDION (layout/group)
class FormInputAccordion extends FormInput {
  final String label;
  final List<FormInput>? inputs;
  final bool? hidden;

  FormInputAccordion({
    required this.label,
    this.inputs,
    this.hidden,
    super.dynamicFn,
  }) : super(type: ArgumentType.accordion);
}

// HORIZONTAL STACK (layout/group)
class FormInputHStack extends FormInput {
  final List<FormInput>? inputs;
  final bool? hidden;

  FormInputHStack({this.inputs, this.hidden, super.dynamicFn})
    : super(type: ArgumentType.hStack);
}

// BANNER (info, warning, etc.)
class FormInputBanner extends FormInput {
  final List<FormInput>? inputs;
  final bool? hidden;
  final Color? color;

  FormInputBanner({this.inputs, this.hidden, this.color, super.dynamicFn})
    : super(type: ArgumentType.banner);
}

// MARKDOWN
class FormInputMarkdown extends FormInput {
  final String content;
  final bool? hidden;

  FormInputMarkdown({required this.content, this.hidden, super.dynamicFn})
    : super(type: ArgumentType.markdown);
}

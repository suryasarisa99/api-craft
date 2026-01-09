import 'dart:async';
import 'dart:ui';

import 'package:api_craft/core/models/models.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// dynamic?: (ctx, args) => Promise<Partial<FormInputEditor>>;
typedef DynamicFn =
    FutureOr<dynamic> Function(WidgetRef ctx, CallTemplateFunctionArgs args);

abstract class FormInput {
  final ArgumentType type;
  final DynamicFn? dynamicFn;
  final bool? hidden;

  FormInput({required this.type, this.dynamicFn, this.hidden});

  FormInput copyWith({DynamicFn? dynamicFn, bool? hidden});

  FormInput applyOverrides(Map<String, dynamic>? overrides);
}

abstract class FormInputBase extends FormInput {
  final String name;
  final String? label;
  final String? placeholder;
  final dynamic defaultValue;
  final bool? optional;
  final bool? disabled;
  final bool? hideLabel;
  final String? description;

  FormInputBase({
    required this.name,
    this.label,
    this.placeholder,
    this.defaultValue,
    this.optional,
    this.disabled,
    this.hideLabel,
    this.description,

    // super parameters
    required super.type,
    super.dynamicFn,
    super.hidden,
  });

  @override
  FormInputBase applyOverrides(Map<String, dynamic>? overrides) {
    if (overrides == null) return this;
    return copyWith(
      label: overrides['label'] as String? ?? label,
      placeholder: overrides['placeholder'] as String? ?? placeholder,
      defaultValue: overrides['defaultValue'] ?? defaultValue,
      optional: overrides['optional'] as bool? ?? optional,
      hidden: overrides['hidden'] as bool? ?? hidden,
      disabled: overrides['disabled'] as bool? ?? disabled,
      hideLabel: overrides['hideLabel'] as bool? ?? hideLabel,
      description: overrides['description'] as String? ?? description,
    );
  }

  @override
  FormInputBase copyWith({
    String? name,
    String? label,
    String? placeholder,
    dynamic defaultValue,
    bool? optional,
    bool? hidden,
    bool? disabled,
    bool? hideLabel,
    String? description,
    DynamicFn? dynamicFn,
  });
}

// todo need to define this later

class FormInputText extends FormInputBase {
  final bool password;
  final bool multiLine;

  FormInputText({
    this.password = false,
    this.multiLine = false,
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

  @override
  FormInputText copyWith({
    String? name,
    String? label,
    String? placeholder,
    dynamic defaultValue,
    bool? optional,
    bool? hidden,
    bool? disabled,
    bool? hideLabel,
    String? description,
    DynamicFn? dynamicFn,
    bool? password,
    bool? multiLine,
  }) {
    return FormInputText(
      name: name ?? this.name,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      defaultValue: defaultValue ?? this.defaultValue,
      optional: optional ?? this.optional,
      hidden: hidden ?? this.hidden,
      disabled: disabled ?? this.disabled,
      hideLabel: hideLabel ?? this.hideLabel,
      description: description ?? this.description,
      dynamicFn: dynamicFn ?? this.dynamicFn,
      password: password ?? this.password,
      multiLine: multiLine ?? this.multiLine,
    );
  }
}

class FormInputEditor extends FormInputBase {
  final String language; // Todo: create enum for languages
  final bool hideGutter;
  final bool readOnly;
  final List<dynamic>? completionOptions; //Todo define type

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

  @override
  FormInputEditor copyWith({
    String? name,
    String? label,
    String? placeholder,
    dynamic defaultValue,
    bool? optional,
    bool? hidden,
    bool? disabled,
    bool? hideLabel,
    String? description,
    DynamicFn? dynamicFn,
    String? language,
    bool? hideGutter,
    bool? readOnly,
    List<dynamic>? completionOptions,
  }) {
    return FormInputEditor(
      name: name ?? this.name,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      defaultValue: defaultValue ?? this.defaultValue,
      optional: optional ?? this.optional,
      hidden: hidden ?? this.hidden,
      disabled: disabled ?? this.disabled,
      hideLabel: hideLabel ?? this.hideLabel,
      description: description ?? this.description,
      dynamicFn: dynamicFn ?? this.dynamicFn,
      language: language ?? this.language,
      hideGutter: hideGutter ?? this.hideGutter,
      readOnly: readOnly ?? this.readOnly,
      completionOptions: completionOptions ?? this.completionOptions,
    );
  }
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

  @override
  FormInputCheckbox copyWith({
    String? name,
    String? label,
    String? placeholder,
    dynamic defaultValue,
    bool? optional,
    bool? hidden,
    bool? disabled,
    bool? hideLabel,
    String? description,
    DynamicFn? dynamicFn,
  }) {
    return FormInputCheckbox(
      name: name ?? this.name,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      defaultValue: defaultValue ?? this.defaultValue,
      optional: optional ?? this.optional,
      hidden: hidden ?? this.hidden,
      disabled: disabled ?? this.disabled,
      hideLabel: hideLabel ?? this.hideLabel,
      description: description ?? this.description,
      dynamicFn: dynamicFn ?? this.dynamicFn,
    );
  }
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

  @override
  FormInputSelect copyWith({
    String? name,
    String? label,
    String? placeholder,
    dynamic defaultValue,
    bool? optional,
    bool? hidden,
    bool? disabled,
    bool? hideLabel,
    String? description,
    DynamicFn? dynamicFn,
    List<FormInputSelectOption>? options,
  }) {
    return FormInputSelect(
      name: name ?? this.name,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      defaultValue: defaultValue ?? this.defaultValue,
      optional: optional ?? this.optional,
      hidden: hidden ?? this.hidden,
      disabled: disabled ?? this.disabled,
      hideLabel: hideLabel ?? this.hideLabel,
      description: description ?? this.description,
      dynamicFn: dynamicFn ?? this.dynamicFn,
      options: options ?? this.options,
    );
  }
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

  @override
  FormInputFile copyWith({
    String? name,
    String? label,
    String? placeholder,
    dynamic defaultValue,
    bool? optional,
    bool? hidden,
    bool? disabled,
    bool? hideLabel,
    String? description,
    DynamicFn? dynamicFn,
    String? title,
    bool? multiple,
    bool? directory,
    String? defaultPath,
    List<FileFilter>? filters,
  }) {
    return FormInputFile(
      title: title ?? this.title,
      multiple: multiple ?? this.multiple,
      directory: directory ?? this.directory,
      defaultPath: defaultPath ?? this.defaultPath,
      filters: filters ?? this.filters,
      name: name ?? this.name,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      defaultValue: defaultValue ?? this.defaultValue,
      optional: optional ?? this.optional,
      hidden: hidden ?? this.hidden,
      disabled: disabled ?? this.disabled,
      hideLabel: hideLabel ?? this.hideLabel,
      description: description ?? this.description,
      dynamicFn: dynamicFn ?? this.dynamicFn,
    );
  }
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

  @override
  FormInputHttpRequest copyWith({
    String? name,
    String? label,
    String? placeholder,
    dynamic defaultValue,
    bool? optional,
    bool? hidden,
    bool? disabled,
    bool? hideLabel,
    String? description,
    DynamicFn? dynamicFn,
  }) {
    return FormInputHttpRequest(
      name: name ?? this.name,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      defaultValue: defaultValue ?? this.defaultValue,
      optional: optional ?? this.optional,
      hidden: hidden ?? this.hidden,
      disabled: disabled ?? this.disabled,
      hideLabel: hideLabel ?? this.hideLabel,
      description: description ?? this.description,
      dynamicFn: dynamicFn ?? this.dynamicFn,
    );
  }
}

// ACCORDION (layout/group)
class FormInputAccordion extends FormInput {
  final String label;
  final List<FormInput>? inputs;

  FormInputAccordion({
    required this.label,
    this.inputs,
    super.hidden,
    super.dynamicFn,
  }) : super(type: ArgumentType.accordion);

  @override
  FormInputAccordion applyOverrides(Map<String, dynamic>? overrides) {
    if (overrides == null) return this;
    return copyWith(
      label: overrides['label'] as String? ?? label,
      hidden: overrides['hidden'] as bool? ?? hidden,
    );
  }

  @override
  FormInputAccordion copyWith({
    String? label,
    List<FormInput>? inputs,
    bool? hidden,
    DynamicFn? dynamicFn,
  }) {
    return FormInputAccordion(
      label: label ?? this.label,
      inputs: inputs ?? this.inputs,
      hidden: hidden ?? this.hidden,
      dynamicFn: dynamicFn ?? this.dynamicFn,
    );
  }
}

// HORIZONTAL STACK (layout/group)
class FormInputHStack extends FormInput {
  final List<FormInput>? inputs;

  FormInputHStack({this.inputs, super.hidden, super.dynamicFn})
    : super(type: ArgumentType.hStack);

  @override
  FormInputHStack applyOverrides(Map<String, dynamic>? overrides) {
    if (overrides == null) return this;
    return copyWith(hidden: overrides['hidden'] as bool? ?? hidden);
  }

  @override
  FormInputHStack copyWith({
    List<FormInput>? inputs,
    bool? hidden,
    DynamicFn? dynamicFn,
  }) {
    return FormInputHStack(
      inputs: inputs ?? this.inputs,
      hidden: hidden ?? this.hidden,
      dynamicFn: dynamicFn ?? this.dynamicFn,
    );
  }
}

// BANNER (info, warning, etc.)
class FormInputBanner extends FormInput {
  final List<FormInput>? inputs;
  final Color? color;

  FormInputBanner({this.inputs, super.hidden, this.color, super.dynamicFn})
    : super(type: ArgumentType.banner);

  @override
  FormInputBanner applyOverrides(Map<String, dynamic>? overrides) {
    if (overrides == null) return this;
    return copyWith(
      hidden: overrides['hidden'] as bool? ?? hidden,
      color: overrides['color'] as Color? ?? color,
    );
  }

  @override
  FormInputBanner copyWith({
    List<FormInput>? inputs,
    bool? hidden,
    Color? color,
    DynamicFn? dynamicFn,
  }) {
    return FormInputBanner(
      inputs: inputs ?? this.inputs,
      hidden: hidden ?? this.hidden,
      color: color ?? this.color,
      dynamicFn: dynamicFn ?? this.dynamicFn,
    );
  }
}

// MARKDOWN
class FormInputMarkdown extends FormInput {
  final String content;

  FormInputMarkdown({required this.content, super.hidden, super.dynamicFn})
    : super(type: ArgumentType.markdown);

  @override
  FormInputMarkdown applyOverrides(Map<String, dynamic>? overrides) {
    if (overrides == null) return this;
    return copyWith(
      content: overrides['content'] as String? ?? content,
      hidden: overrides['hidden'] as bool? ?? hidden,
    );
  }

  @override
  FormInputMarkdown copyWith({
    String? content,
    bool? hidden,
    DynamicFn? dynamicFn,
  }) {
    return FormInputMarkdown(
      content: content ?? this.content,
      hidden: hidden ?? this.hidden,
      dynamicFn: dynamicFn ?? this.dynamicFn,
    );
  }
}

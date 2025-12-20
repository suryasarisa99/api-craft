import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/variable_text_field_custom.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:collection/collection.dart';

class FormInputWidget extends StatelessWidget {
  final List<FormInput> inputs;
  final bool isVertical;
  final String? id;
  final Map<String, dynamic> data;
  final Function(String key, dynamic value) onChanged;
  const FormInputWidget({
    super.key,
    required this.inputs,
    required this.onChanged,
    required this.data,
    this.isVertical = true,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return isVertical
        ? Column(spacing: 16, children: _buildInputWidgets())
        : Row(
            spacing: 8,
            children: _buildInputWidgets()
                .map((w) => Expanded(child: w))
                .toList(),
          );
  }

  List<Widget> _buildInputWidgets() {
    return inputs.map((input) {
      return DynamicFormInputWrapper(
        input: input,
        data: data,
        id: id,
        onChanged: onChanged,
      );
    }).toList();
  }
}

class DynamicFormInputWrapper extends ConsumerStatefulWidget {
  final FormInput input;
  final Map<String, dynamic> data;
  final String? id;
  final Function(String key, dynamic value) onChanged;

  const DynamicFormInputWrapper({
    super.key,
    required this.input,
    required this.data,
    required this.id,
    required this.onChanged,
  });

  @override
  ConsumerState<DynamicFormInputWrapper> createState() =>
      _DynamicFormInputWrapperState();
}

class _DynamicFormInputWrapperState
    extends ConsumerState<DynamicFormInputWrapper> {
  Map<String, dynamic>? _dynamicOverrides;
  // ignore: unused_field
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDynamicFn();
  }

  @override
  void didUpdateWidget(DynamicFormInputWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    const eq = MapEquality();
    if (!eq.equals(oldWidget.data, widget.data) ||
        oldWidget.input != widget.input) {
      _runDynamicFn();
    }
  }

  Future<void> _runDynamicFn() async {
    if (widget.input.dynamicFn == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final result = await widget.input.dynamicFn!(
        ref,
        CallTemplateFunctionArgs(values: widget.data, purpose: Purpose.preview),
      );

      if (result is Map<String, dynamic> && mounted) {
        setState(() {
          _dynamicOverrides = result;
        });
      }
    } catch (e) {
      debugPrint("Error running dynamicFn: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.input;

    // Apply overrides
    final hidden =
        _dynamicOverrides?['hidden'] as bool? ??
        (input is FormInputBase ? input.hidden : false);

    if (hidden == true) {
      return const SizedBox.shrink();
    }

    return switch (input) {
      FormInputSelect selectInput => FormWidgetSelect(
        selectInput: selectInput,
        overrides: _dynamicOverrides,
        value: widget.data[selectInput.name] as String?,
        onChanged: (v) {
          widget.onChanged(selectInput.name, v);
        },
      ),
      FormInputText textInput => FormWidgetText(
        input: textInput,
        overrides: _dynamicOverrides,
        id: widget.id,
        value: widget.data[textInput.name] as String?,
        onChanged: (v) {
          widget.onChanged(textInput.name, v);
        },
      ),
      FormInputCheckbox checkboxInput => FormWidgetCheckbox(
        input: checkboxInput,
        overrides: _dynamicOverrides,
        value: widget.data[checkboxInput.name] as bool?,
        onChanged: (v) {
          widget.onChanged(checkboxInput.name, v);
        },
      ),
      FormInputEditor editorInput => FormWidgetEditor(
        input: editorInput,
        overrides: _dynamicOverrides,
        id: widget.id,
        value: widget.data[editorInput.name] as String?,
        onChanged: (v) {
          widget.onChanged(editorInput.name, v);
        },
      ),
      FormInputFile fileInput => FormWidgetFile(
        input: fileInput,
        overrides: _dynamicOverrides,
        value: widget.data[fileInput.name] as String?,
        onChanged: (v) {
          widget.onChanged(fileInput.name, v);
        },
      ),
      FormInputHStack hStackInput => FormWidgetHStack(
        input: hStackInput,
        onChanged: widget.onChanged,
        data: widget.data,
        id: widget.id,
      ),
      FormInputAccordion accordionInput => FormWidgetAccordion(
        input: accordionInput,
        onChanged: widget.onChanged,
        data: widget.data,
        id: widget.id,
      ),
      FormInputBanner bannerInput => FormWidgetBanner(
        input: bannerInput,
        onChanged: widget.onChanged,
        data: widget.data,
        id: widget.id,
      ),
      FormInputMarkdown markdownInput => FormWidgetMarkdown(
        input: markdownInput,
        overrides: _dynamicOverrides,
      ),
      FormInputHttpRequest httpRequestInput => FormWidgetHttpRequest(
        input: httpRequestInput,
        overrides: _dynamicOverrides,
        value: widget.data[httpRequestInput.name],
        onChanged: (value) => widget.onChanged(httpRequestInput.name, value),
      ),
      _ => SizedBox.shrink(),
    };
  }
}

class FormWidgetSelect extends StatelessWidget {
  final FormInputSelect selectInput;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final Map<String, dynamic>? overrides;
  const FormWidgetSelect({
    super.key,
    required this.selectInput,
    this.value,
    this.onChanged,
    this.overrides,
  });

  @override
  Widget build(BuildContext context) {
    final label = overrides?['label'] as String? ?? selectInput.label;
    final defaultValue = overrides?['defaultValue'] ?? selectInput.defaultValue;
    final optional =
        overrides?['optional'] as bool? ?? selectInput.optional == true;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      initialValue: value ?? defaultValue,
      validator: !optional
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
      items: selectInput.options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class FormWidgetText extends StatelessWidget {
  final FormInputText input;
  final String? id;
  final ValueChanged<String?>? onChanged;
  final String? value;
  final Map<String, dynamic>? overrides;

  const FormWidgetText({
    super.key,
    required this.input,
    this.onChanged,
    this.value,
    required this.id,
    this.overrides,
  });

  @override
  Widget build(BuildContext context) {
    final label = overrides?['label'] as String? ?? input.label;
    final placeholder =
        overrides?['placeholder'] as String? ?? input.placeholder;
    final defaultValue = overrides?['defaultValue'] ?? input.defaultValue;

    return VariableTextFieldCustom(
      id: id,
      decoration: InputDecoration(labelText: label, hintText: placeholder),
      initialValue: value ?? defaultValue,
      onChanged: (val) {
        onChanged?.call(val);
      },
    );
  }
}

class FormWidgetHStack extends StatelessWidget {
  final FormInputHStack input;
  final String? id;
  final Map<String, dynamic> data;
  final Function(String key, dynamic value) onChanged;
  const FormWidgetHStack({
    super.key,
    required this.input,
    required this.data,
    required this.onChanged,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return FormInputWidget(
      id: id,
      inputs: input.inputs ?? [],
      isVertical: false,
      data: data,
      onChanged: onChanged,
    );
  }
}

class FormWidgetHttpRequest extends ConsumerStatefulWidget {
  final FormInputHttpRequest input;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final Map<String, dynamic>? overrides;

  const FormWidgetHttpRequest({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
    this.overrides,
  });

  @override
  ConsumerState<FormWidgetHttpRequest> createState() =>
      _FormWidgetHttpRequestState();
}

class _FormWidgetHttpRequestState extends ConsumerState<FormWidgetHttpRequest> {
  List<RequestNode> requestNodes = [];

  @override
  void initState() {
    super.initState();
    requestNodes = ref
        .read(fileTreeProvider)
        .nodeMap
        .values
        .whereType<RequestNode>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.overrides?['label'] as String? ?? widget.input.label;
    final defaultValue =
        widget.overrides?['defaultValue'] ?? widget.input.defaultValue;
    final optional =
        widget.overrides?['optional'] as bool? ?? widget.input.optional == true;

    // show picker
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      initialValue: widget.value ?? defaultValue,
      validator: !optional
          ? (val) {
              if (val == null || val.isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
      items: requestNodes
          .map(
            (node) => DropdownMenuItem<String>(
              value: node.id,
              child: Text(node.name),
            ),
          )
          .toList(),
      onChanged: widget.onChanged,
    );
  }
}

class FormWidgetCheckbox extends StatelessWidget {
  final FormInputCheckbox input;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Map<String, dynamic>? overrides;

  const FormWidgetCheckbox({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
    this.overrides,
  });

  @override
  Widget build(BuildContext context) {
    final label = overrides?['label'] as String? ?? input.label ?? input.name;
    final defaultValue =
        overrides?['defaultValue'] as bool? ??
        input.defaultValue as bool? ??
        false;

    return CheckboxListTile(
      title: Text(label),
      value: value ?? defaultValue,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class FormWidgetEditor extends StatelessWidget {
  final FormInputEditor input;
  final String? value;
  final String? id;
  final ValueChanged<String?>? onChanged;
  final Map<String, dynamic>? overrides;

  const FormWidgetEditor({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
    required this.id,
    this.overrides,
  });

  @override
  Widget build(BuildContext context) {
    final label = overrides?['label'] as String? ?? input.label;
    final defaultValue =
        overrides?['defaultValue'] as String? ?? input.defaultValue as String?;

    return VariableTextFieldCustom(
      id: id,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      initialValue: value ?? defaultValue,
      maxLines: 10,
      onChanged: onChanged,
    );
  }
}

class FormWidgetFile extends StatelessWidget {
  final FormInputFile input;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final Map<String, dynamic>? overrides;

  const FormWidgetFile({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
    this.overrides,
  });

  @override
  Widget build(BuildContext context) {
    final label = overrides?['label'] as String? ?? input.label ?? input.title;
    final defaultValue =
        overrides?['defaultValue'] as String? ?? input.defaultValue as String?;

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: InputDecoration(labelText: label),
            initialValue: value ?? defaultValue,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.file_open),
          onPressed: () {
            // Placeholder: would use file_picker here
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("File picking requires file_picker package"),
              ),
            );
          },
        ),
      ],
    );
  }
}

class FormWidgetAccordion extends StatefulWidget {
  final FormInputAccordion input;
  final Map<String, dynamic> data;
  final String? id;
  final Function(String key, dynamic value) onChanged;

  const FormWidgetAccordion({
    super.key,
    required this.input,
    required this.data,
    required this.onChanged,
    required this.id,
  });

  @override
  State<FormWidgetAccordion> createState() => _FormWidgetAccordionState();
}

class _FormWidgetAccordionState extends State<FormWidgetAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(widget.input.label),
      initiallyExpanded: _isExpanded,
      onExpansionChanged: (val) => setState(() => _isExpanded = val),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: FormInputWidget(
            id: widget.id,
            inputs: widget.input.inputs ?? [],
            onChanged: widget.onChanged,
            data: widget.data,
          ),
        ),
      ],
    );
  }
}

class FormWidgetBanner extends StatelessWidget {
  final FormInputBanner input;
  final Map<String, dynamic> data;
  final String? id;
  final Function(String key, dynamic value) onChanged;

  const FormWidgetBanner({
    super.key,
    required this.input,
    required this.data,
    required this.onChanged,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    final color = input.color ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: FormInputWidget(
        id: id,
        inputs: input.inputs ?? [],
        onChanged: onChanged,
        data: data,
      ),
    );
  }
}

class FormWidgetMarkdown extends StatelessWidget {
  final FormInputMarkdown input;
  final Map<String, dynamic>? overrides;

  const FormWidgetMarkdown({super.key, required this.input, this.overrides});

  @override
  Widget build(BuildContext context) {
    final content = overrides?['content'] as String? ?? input.content;
    // Simple text for now since flutter_markdown is missing
    return Text(content);
  }
}

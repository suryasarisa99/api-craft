import 'package:api_craft/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/template-functions/models/template_context.dart';
import 'package:flutter/material.dart';

class FormInputWidget extends StatelessWidget {
  final List<FormInput> inputs;
  final bool isVertical;
  final Map<String, dynamic> data;
  final Function(String key, dynamic value) onChanged;
  const FormInputWidget({
    super.key,
    required this.inputs,
    required this.onChanged,
    required this.data,
    this.isVertical = true,
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
      if (input is FormInputBase && input.hidden == true) {
        return SizedBox.shrink();
      }
      return switch (input) {
        FormInputSelect selectInput => FormWidgetSelect(
          selectInput: selectInput,
          value: data[selectInput.name] as String?,
          onChanged: (v) {
            onChanged(selectInput.name, v);
          },
        ),
        FormInputText textInput => FormWidgetText(
          input: textInput,
          value: data[textInput.name] as String?,
          onChanged: (v) {
            onChanged(textInput.name, v);
          },
        ),
        FormInputHStack hStackInput => FormWidgetHStack(
          input: hStackInput,
          onChanged: onChanged,
          data: data,
        ),
        FormInputHttpRequest httpRequestInput => FormWidgetHttpRequest(
          input: httpRequestInput,
          value: data[httpRequestInput.name],
          onChanged: (value) => onChanged(httpRequestInput.name, value),
        ),
        // Add more FormInput types here as needed
        _ => SizedBox.shrink(), // Fallback for unsupported input types
      };
    }).toList();
  }
}

class FormWidgetSelect extends StatelessWidget {
  final FormInputSelect selectInput;
  final String? value;
  final ValueChanged<String?>? onChanged;
  const FormWidgetSelect({
    super.key,
    required this.selectInput,
    this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: selectInput.label),
      initialValue: value ?? selectInput.defaultValue,
      validator: (selectInput.optional != true)
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

class FormWidgetText extends ConsumerStatefulWidget {
  final FormInputText input;
  final ValueChanged<String?>? onChanged;
  final String? value;
  const FormWidgetText({
    super.key,
    required this.input,
    this.onChanged,
    this.value,
  });

  @override
  ConsumerState<FormWidgetText> createState() => _FormWidgetTextState();
}

class _FormWidgetTextState extends ConsumerState<FormWidgetText> {
  dynamic dynamicResult;

  @override
  void initState() {
    super.initState();
    runDynamicFn(ref);
  }

  void runDynamicFn(WidgetRef ref) async {
    if (widget.input.dynamicFn != null) {
      final result = await widget.input.dynamicFn!.call(
        WidgetRefTemplateContext(ref),
        CallTemplateFunctionArgs(values: {}, purpose: Purpose.preview),
      );
      setState(() {
        dynamicResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // if (dynamicResult?['hidden'] as bool? ?? false) {
    //   return SizedBox.shrink();
    // }

    return TextFormField(
      decoration: InputDecoration(labelText: widget.input.label),
      initialValue: widget.value ?? widget.input.defaultValue,
      onChanged: (val) {
        widget.onChanged?.call(val);
      },
    );
  }
}

class FormWidgetHStack extends StatelessWidget {
  final FormInputHStack input;
  final Map<String, dynamic> data;
  final Function(String key, dynamic value) onChanged;
  const FormWidgetHStack({
    super.key,
    required this.input,
    required this.data,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormInputWidget(
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

  const FormWidgetHttpRequest({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
  });

  @override
  ConsumerState<FormWidgetHttpRequest> createState() =>
      _FormWidgetHttpRequestState();
}

class _FormWidgetHttpRequestState extends ConsumerState<FormWidgetHttpRequest> {
  late List<RequestNode> requestNodes;
  late final String? initialValue = widget.value ?? widget.input.defaultValue;

  @override
  void initState() {
    super.initState();
    requestNodes = ref
        .read(fileTreeProvider)
        .nodeMap
        .values
        .whereType<RequestNode>()
        .toList();
    debugPrint("ids: ${requestNodes.map((e) => e.id).toList()}");
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "initial value: ${widget.value ?? widget.input.defaultValue ?? requestNodes.first.id}",
    );
    // show picker
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: widget.input.label),
      initialValue: initialValue,
      validator: (widget.input.optional != true)
          ? (value) {
              if (value == null || value.isEmpty) {
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

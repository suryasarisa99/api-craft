import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter/material.dart';

class FormInputWidget extends StatelessWidget {
  final List<FormInput> inputs;
  final bool isVertical;
  const FormInputWidget({
    super.key,
    required this.inputs,
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
      return switch (input) {
        FormInputSelect selectInput => FormWidgetSelect(
          selectInput: selectInput,
          onChanged: (v) {},
        ),
        FormInputText textInput => FormWidgetText(input: textInput),
        FormInputHStack hStackInput => FormWidgetHStack(input: hStackInput),
        FormInputHttpRequest httpRequestInput => FormWidgetHttpRequest(
          input: httpRequestInput,
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
        ref,
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
  const FormWidgetHStack({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    return FormInputWidget(inputs: input.inputs ?? [], isVertical: false);
  }
}

class FormWidgetHttpRequest extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(labelText: input.label),
      initialValue: value ?? input.defaultValue,
      onChanged: onChanged,
    );
  }
}

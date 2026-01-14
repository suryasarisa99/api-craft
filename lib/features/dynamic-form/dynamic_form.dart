import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/variable_text_field_custom.dart';
import 'package:dotted_decoration/dotted_decoration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:collection/collection.dart';

class DynamicForm extends ConsumerStatefulWidget {
  final List<FormInput> inputs;
  final bool isVertical;
  final String? id;
  final Map<String, dynamic> data;
  final Function(String key, dynamic value) onChanged;
  const DynamicForm({
    super.key,
    required this.inputs,
    required this.onChanged,
    required this.data,
    this.isVertical = true,
    required this.id,
  });

  @override
  ConsumerState<DynamicForm> createState() => _FormInputWidgetState();
}

class _FormInputWidgetState extends ConsumerState<DynamicForm> {
  List<Map<String, dynamic>?> _overrides = [];
  // bool _isLoadingDynamicFns = false;

  @override
  void initState() {
    super.initState();
    _initOverrides();
    _runAllDynamicFn();
  }

  @override
  void didUpdateWidget(DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    const eq = MapEquality();
    bool inputsChanged = !const ListEquality().equals(
      oldWidget.inputs,
      widget.inputs,
    );
    bool dataChanged = !eq.equals(oldWidget.data, widget.data);

    if (inputsChanged) {
      _initOverrides();
    }

    if (inputsChanged || dataChanged) {
      _runAllDynamicFn();
    }
  }

  void _initOverrides() {
    _overrides = List.filled(widget.inputs.length, null);
  }

  Future<void> _runAllDynamicFn() async {
    // if (mounted) setState(() => _isLoadingDynamicFns = true);

    List<Future<void>> futures = [];
    for (int i = 0; i < widget.inputs.length; i++) {
      final input = widget.inputs[i];
      if (input.dynamicFn == null) continue;

      // Capture current data for the call
      final currentData = widget.data;
      final currentIndex = i; // Capture index for async update

      futures.add(() async {
        try {
          final result = await input.dynamicFn!(
            ref,
            CallTemplateFunctionArgs(
              values: currentData,
              purpose: Purpose.preview,
            ),
          );

          if (mounted && result is Map<String, dynamic>) {
            // Only update if the input at this index is still the same input
            // and the index is within bounds.
            if (currentIndex < widget.inputs.length &&
                widget.inputs[currentIndex] == input) {
              setState(() {
                _overrides[currentIndex] = result;
              });
            }
          }
        } catch (e) {
          debugPrint(
            "Error running dynamicFn for ${input.type} at index $currentIndex: $e",
          );
        }
      }());
    }
    await Future.wait(futures);
    // if (mounted) setState(() => _isLoadingDynamicFns = false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleChildren = <Widget>[];

    for (int i = 0; i < widget.inputs.length; i++) {
      final input = widget.inputs[i];
      final override = (_overrides.length > i) ? _overrides[i] : null;

      final mergedInput = input.applyOverrides(override);

      if (mergedInput.hidden == true) continue;

      Widget child = _buildInputChild(mergedInput);

      if (!widget.isVertical) {
        child = Expanded(child: child);
      }
      visibleChildren.add(child);
    }
    return widget.isVertical
        ? Column(spacing: 14, children: visibleChildren)
        : Row(spacing: 8, children: visibleChildren);
  }

  Widget _buildInputChild(FormInput input) {
    return switch (input) {
      FormInputSelect selectInput => FormWidgetSelect(
        selectInput: selectInput,
        value: widget.data[selectInput.name] as String?,
        onChanged: (v) => widget.onChanged(selectInput.name, v),
      ),
      FormInputText textInput => FormWidgetText(
        input: textInput,
        id: widget.id,
        value: widget.data[textInput.name] as String?,
        onChanged: (v) => widget.onChanged(textInput.name, v),
      ),
      FormInputCheckbox checkboxInput => FormWidgetCheckbox(
        input: checkboxInput,
        value: widget.data[checkboxInput.name] as bool?,
        onChanged: (v) => widget.onChanged(checkboxInput.name, v),
      ),
      FormInputEditor editorInput => FormWidgetEditor(
        input: editorInput,
        id: widget.id,
        value: widget.data[editorInput.name] as String?,
        onChanged: (v) => widget.onChanged(editorInput.name, v),
      ),
      FormInputFile fileInput => FormWidgetFile(
        input: fileInput,
        value: widget.data[fileInput.name] as String?,
        onChanged: (v) => widget.onChanged(fileInput.name, v),
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
      ),
      FormInputHttpRequest httpRequestInput => FormWidgetHttpRequest(
        input: httpRequestInput,
        value: widget.data[httpRequestInput.name],
        onChanged: (value) => widget.onChanged(httpRequestInput.name, value),
      ),
      _ => const SizedBox.shrink(),
    };
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
    final label = selectInput.label;
    final defaultValue = selectInput.defaultValue;
    final optional = selectInput.optional == true;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      ),
      dropdownColor: const Color.fromARGB(255, 45, 45, 45),
      isDense: true,
      itemHeight: 28,
      style: TextStyle(fontSize: 14),
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

  const FormWidgetText({
    super.key,
    required this.input,
    this.onChanged,
    this.value,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    final label = input.label;
    final placeholder = input.placeholder;
    final defaultValue = input.defaultValue;

    return VariableTextFieldCustom(
      id: id,

      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      ),
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
    return DynamicForm(
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
  List<RequestNode> requestNodes = [];

  @override
  void initState() {
    super.initState();
    final nodes = ref.read(fileTreeProvider).nodeMap.values;
    // only http and graphql requests
    requestNodes = [
      for (final node in nodes)
        if (node is RequestNode && node.requestType == RequestType.http) node,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.input.label;
    final defaultValue = widget.input.defaultValue;
    final optional = widget.input.optional == true;

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

  const FormWidgetCheckbox({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = input.label ?? input.name;
    final defaultValue = input.defaultValue as bool? ?? false;

    return CheckboxListTile(
      dense: true,
      contentPadding: .zero,
      title: Text(label),
      value: value ?? defaultValue,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );
    // return Transform.scale(
    //   scale: 1,
    //   child: SwitchListTile(
    //     title: Text(label),
    //     controlAffinity: ListTileControlAffinity.leading,
    //     value: value ?? defaultValue,
    //     onChanged: onChanged,
    //   ),
    // );
  }
}

class FormWidgetEditor extends StatelessWidget {
  final FormInputEditor input;
  final String? value;
  final String? id;
  final ValueChanged<String?>? onChanged;

  const FormWidgetEditor({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    final label = input.label;
    final defaultValue = input.defaultValue as String?;

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

  const FormWidgetFile({
    super.key,
    required this.input,
    this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = input.label ?? input.title;
    final defaultValue = input.defaultValue as String?;

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
    return DecoratedBox(
      decoration: DottedDecoration(
        shape: Shape.box,
        color: const Color.fromARGB(255, 109, 109, 109),
        dash: [5, 3],
        borderRadius: BorderRadius.circular(6),
      ),
      child: ExpansionTile(
        title: Text(widget.input.label),
        dense: true,
        visualDensity: VisualDensity.compact,
        minTileHeight: 28,
        backgroundColor: const Color(0xFF252525),
        collapsedBackgroundColor: const Color(0xFF252525),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        initiallyExpanded: _isExpanded,
        childrenPadding: .symmetric(horizontal: 18, vertical: 14),
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        children: [
          DynamicForm(
            id: widget.id,
            inputs: widget.input.inputs ?? [],
            onChanged: widget.onChanged,
            data: widget.data,
          ),
        ],
      ),
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
      child: DynamicForm(
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

  const FormWidgetMarkdown({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    final content = input.content;
    // Simple text for now since flutter_markdown is missing
    return Text(content);
  }
}

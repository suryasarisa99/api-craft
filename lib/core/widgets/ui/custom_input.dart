import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/core/widgets/ui/variable_text_field_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomInput extends StatefulWidget {
  final Function()? onTap;
  final String? id;
  final Function(String)? onFieldSubmitted;
  final Function(String)? onUpdate;
  final Function(String)? onChanged;
  final Function(String)? onTapOutside;
  final Function(String?)? onExtraInputChange;
  final TextEditingController? controller;
  final bool enableSuggestions;
  final String value;
  final bool isEnabled;
  final bool isExtra;
  final FocusNode? focusNode;
  final bool autofocus;
  // final String flowId;

  const CustomInput({
    required this.id,
    this.autofocus = false,
    this.onFieldSubmitted,
    this.enableSuggestions = true,
    this.controller,
    this.onChanged,
    this.onTap,
    required this.value,
    this.onTapOutside,
    this.onUpdate,
    this.focusNode,
    this.isEnabled = true,
    this.isExtra = false,
    this.onExtraInputChange,
    super.key,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.value);
  late final Debouncer debouncer = Debouncer(const Duration(milliseconds: 350));
  static const newRowByFocus = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant CustomInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExtra) {
      //reset text
      _controller.text = "";
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VariableTextFieldCustom(
      id: widget.id,
      enableSuggestions: widget.enableSuggestions,
      focusNode: widget.focusNode,
      controller: _controller,
      onKeyEvent: (hasFocus, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          FocusScope.of(context).unfocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onChanged: (v) {
        if (widget.isExtra && !newRowByFocus) {
          widget.onExtraInputChange?.call(v);
        } else {
          debouncer.run(() {
            widget.onUpdate?.call(_controller.text);
          });
        }
      },
    );
  }
}

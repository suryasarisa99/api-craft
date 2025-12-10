import 'package:api_craft/utils/debouncer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomInput extends StatefulWidget {
  final Function()? onTap;
  final Function(String)? onFieldSubmitted;
  final Function(String)? onUpdate;
  final Function(String)? onChanged;
  final Function(String)? onTapOutside;
  final Function(String?)? onExtraInputChange;
  final String value;
  final bool isEnabled;
  final bool isExtra;
  final FocusNode? focusNode;
  final bool autofocus;
  // final String flowId;

  const CustomInput({
    // required this.flowId,
    this.autofocus = false,
    this.onFieldSubmitted,
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
  late final TextEditingController _controller;
  late final Debouncer debouncer = Debouncer(const Duration(milliseconds: 350));
  VoidCallback? _initialFocusListener;
  @override
  void initState() {
    super.initState();

    _controller = TextEditingController.fromValue(
      TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CustomInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (oldWidget.flowId != widget.flowId) {
    //   _controller.text = widget.value;
    // }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      canRequestFocus: false,

      onFocusChange: (hasFocus) {
        if (hasFocus) {
          if (widget.isExtra) {
            // widget.onExtraInputChange?.call();
          } else {
            // widget.onUpdate?.call(_controller.text);
          }
        } else {
          debugPrint("losing focus");
          // tableFocusNode.requestFocus();
        }
      },
      onKeyEvent: (hasFocus, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          FocusScope.of(context).unfocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextFormField(
        controller: _controller,
        focusNode: widget.focusNode,
        style: TextStyle(
          fontSize: 14,
          color: widget.isEnabled ? Colors.white : Colors.grey[600],
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const .symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: .new(color: Colors.grey[600]!, width: 0.6),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: const .fromARGB(150, 117, 117, 117),
              width: 0.6,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(
              color: .fromARGB(210, 255, 167, 95),
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: .new(color: Colors.grey[800]!, width: 1),
          ),
        ),
        onChanged: (v) {
          if (widget.isExtra) {
            widget.onExtraInputChange?.call(v);
          } else {
            debouncer.run(() {
              widget.onUpdate?.call(_controller.text);
            });
          }
        },
        onTapOutside: (e) {
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

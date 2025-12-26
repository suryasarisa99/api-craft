import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:flutter/material.dart';

Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  String? placeholder,
  String? initialValue,
  Function(String s)? onConfirmed,
  Function()? onCancelled,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return InputDialog(
        title: title,
        placeholder: placeholder,
        initialValue: initialValue,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      );
    },
  );
}

class InputDialog extends StatelessWidget {
  InputDialog({
    super.key,
    this.onCancelled,
    required this.onConfirmed,
    required this.title,
    this.placeholder,
    this.initialValue,
  });
  final Function(String s)? onConfirmed;
  final Function()? onCancelled;
  final String? placeholder;
  final String title;
  final String? initialValue;

  late final textController = TextEditingController(text: initialValue);

  void handleSubmit(BuildContext context) {
    final text = textController.text.trim();
    onConfirmed?.call(text);
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      width: 350,
      showCloseButton: false,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Text(title, style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            controller: textController,
            decoration: InputDecoration(hintText: placeholder),
            onSubmitted: (_) => handleSubmit(context),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: .end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCancelled?.call();
                },
                child: Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey[350]),
                ),
              ),
              SizedBox(width: 8),
              FilledButton(
                onPressed: () => handleSubmit(context),
                child: const Text("OK"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

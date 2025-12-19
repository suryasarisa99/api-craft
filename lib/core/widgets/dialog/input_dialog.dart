import 'package:flutter/material.dart';

class InputDialog extends StatelessWidget {
  InputDialog({
    super.key,
    this.onCancelled,
    required this.onConfirmed,
    required this.title,
    required this.placeholder,
  });
  final Function(String s) onConfirmed;
  final Function()? onCancelled;
  final String placeholder;
  final String title;

  final textController = TextEditingController();

  void handleSubmit(BuildContext context) {
    final text = textController.text.trim();
    onConfirmed(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      backgroundColor: Colors.grey[900],
      contentPadding: .only(left: 18, right: 18, top: 12, bottom: 12),
      actionsPadding: .only(bottom: 14, right: 14),
      titlePadding: .only(top: 16, left: 16, right: 16),
      title: Text(title, style: TextStyle(fontSize: 18)),
      content: TextField(
        autofocus: true,
        controller: textController,
        decoration: InputDecoration(hintText: placeholder),
        onSubmitted: (_) => handleSubmit(context),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancelled?.call();
          },
          child: Text("Cancel", style: TextStyle(color: Colors.grey[350])),
        ),
        TextButton(
          onPressed: () => handleSubmit(context),
          child: const Text("OK"),
        ),
      ],
    );
  }
}

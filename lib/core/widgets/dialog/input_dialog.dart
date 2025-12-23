import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:flutter/material.dart';

// class InputDialog extends StatelessWidget {
//   InputDialog({
//     super.key,
//     this.onCancelled,
//     required this.onConfirmed,
//     required this.title,
//     required this.placeholder,
//   });
//   final Function(String s) onConfirmed;
//   final Function()? onCancelled;
//   final String placeholder;
//   final String title;

//   final textController = TextEditingController();

//   void handleSubmit(BuildContext context) {
//     final text = textController.text.trim();
//     onConfirmed(text);
//     Navigator.of(context).pop();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       insetPadding: EdgeInsets.symmetric(horizontal: 0),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
//       backgroundColor: Colors.grey[900],
//       contentPadding: .only(left: 18, right: 18, top: 12, bottom: 12),
//       actionsPadding: .only(bottom: 14, right: 14),
//       titlePadding: .only(top: 16, left: 16, right: 16),
//       title: Text(title, style: TextStyle(fontSize: 18)),
//       content: TextField(
//         autofocus: true,
//         controller: textController,
//         decoration: InputDecoration(hintText: placeholder),
//         onSubmitted: (_) => handleSubmit(context),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () {
//             Navigator.of(context).pop();
//             onCancelled?.call();
//           },
//           child: Text("Cancel", style: TextStyle(color: Colors.grey[350])),
//         ),
//         TextButton(
//           onPressed: () => handleSubmit(context),
//           child: const Text("OK"),
//         ),
//       ],
//     );
//   }
// }

class InputDialog extends StatelessWidget {
  InputDialog({
    super.key,
    this.onCancelled,
    required this.onConfirmed,
    required this.title,
    this.placeholder,
    this.initialValue,
  });
  final Function(String s) onConfirmed;
  final Function()? onCancelled;
  final String? placeholder;
  final String title;
  final String? initialValue;

  late final textController = TextEditingController(text: initialValue);

  void handleSubmit(BuildContext context) {
    final text = textController.text.trim();
    onConfirmed(text);
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

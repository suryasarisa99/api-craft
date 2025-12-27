import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

class JsonViewer extends StatelessWidget {
  final Map<String, dynamic> jsonObj;
  const JsonViewer({super.key, required this.jsonObj});

  @override
  Widget build(BuildContext context) {
    return JsonView.map(
      jsonObj,
      theme: JsonViewTheme(
        backgroundColor: Colors.transparent,
        keyStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        stringStyle: TextStyle(color: Theme.of(context).colorScheme.tertiary),
        doubleStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
        intStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
        boolStyle: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

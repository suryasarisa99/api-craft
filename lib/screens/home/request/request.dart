import 'package:api_craft/widgets/ui/variable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestTab extends ConsumerStatefulWidget {
  const RequestTab({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _RequestTabState();
}

class _RequestTabState extends ConsumerState<RequestTab> {
  final List<Widget> children = const [
    VariableTextField(),
    // Add other tabs here
  ];
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          VariableTextField(),
          SizedBox(height: 16),
          Row(
            children: [
              // LazyLoadIndexedStack(index: , children: children)
            ],
          ),
        ],
      ),
    );
  }
}

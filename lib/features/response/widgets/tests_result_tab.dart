import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:flutter/material.dart';

class TestsResultTab extends StatelessWidget {
  final List<TestResult> results;
  final List<TestResult> assertionResults;

  const TestsResultTab({
    super.key,
    required this.results,
    this.assertionResults = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty && assertionResults.isEmpty) {
      return const Center(child: Text("No tests or assertions run"));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (results.isNotEmpty)
            _buildSection(context, "Test Scripts", results),
          if (results.isNotEmpty && assertionResults.isNotEmpty)
            const Divider(height: 1),
          if (assertionResults.isNotEmpty)
            _buildSection(context, "Assertions", assertionResults),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<TestResult> items,
  ) {
    final passed = items.where((r) => r.status == 'passed').length;
    final failed = items.where((r) => r.status == 'failed').length;

    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Row(
        children: [
          Text(
            "$passed Passed",
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            "$failed Failed",
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ),
      children: items.map((result) {
        final isPassed = result.status == 'passed';
        return ListTile(
          leading: Icon(
            isPassed ? Icons.check_circle : Icons.cancel,
            color: isPassed ? Colors.green : Colors.red,
            size: 20,
          ),
          title: Text(result.description, style: const TextStyle(fontSize: 14)),
          subtitle: !isPassed && result.error != null
              ? Text(
                  result.error!,
                  style: TextStyle(color: Colors.red[300], fontSize: 12),
                )
              : null,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:flutter/material.dart';

class TestsResultTab extends StatelessWidget {
  final List<TestResult> results;

  const TestsResultTab({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text("No tests run"));
    }

    final passed = results.where((r) => r.status == 'passed').length;
    final failed = results.where((r) => r.status == 'failed').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                "Tests Results",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  "$passed Passed",
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  "$failed Failed",
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              final isPassed = result.status == 'passed';
              return ListTile(
                leading: Icon(
                  isPassed ? Icons.check_circle : Icons.cancel,
                  color: isPassed ? Colors.green : Colors.red,
                  size: 20,
                ),
                title: Text(
                  result.description,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: !isPassed && result.error != null
                    ? Text(
                        result.error!,
                        style: TextStyle(color: Colors.red[300], fontSize: 12),
                      )
                    : null,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ResponseInfoTab extends StatelessWidget {
  final RawHttpResponse response;
  const ResponseInfoTab({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final sizeInKb = (response.bodyBytes.length / 1024).toStringAsFixed(2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoRow(
          "Status",
          "${response.statusCode} ${response.statusMessage}",
        ),
        _buildInfoRow("Time", "${response.durationMs} ms"),
        _buildInfoRow("Size", "$sizeInKb KB"),
        _buildInfoRow("Executed At", dateFormat.format(response.executeAt)),
        _buildInfoRow("Protocol", response.protocolVersion),
        _buildInfoRow("Body Type", response.bodyType ?? "Unknown"),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

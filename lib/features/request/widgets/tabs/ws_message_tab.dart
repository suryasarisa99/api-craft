import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';
import 'package:api_craft/features/request/providers/ws_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WsMessageTab extends ConsumerStatefulWidget {
  final String requestId;
  const WsMessageTab({super.key, required this.requestId});

  @override
  ConsumerState<WsMessageTab> createState() => _WsMessageTabState();
}

class _WsMessageTabState extends ConsumerState<WsMessageTab> {
  String _message = "";

  void _sendMessage() {
    if (_message.isEmpty) return;
    ref
        .read(wsRequestProvider(widget.requestId).notifier)
        .sendMessage(_message);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wsRequestProvider(widget.requestId));
    final isConnected = state.isConnected;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: CFCodeEditor(
              text: _message,
              onChanged: (val) => _message = val,
              language: "json", // Default to JSON, maybe add picker later
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: isConnected ? _sendMessage : null,
                icon: const Icon(Icons.send, size: 16),
                label: const Text("Send Message"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

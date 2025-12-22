import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';
import 'package:api_craft/features/request/providers/ws_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'package:suryaicons/duotone_rounded.dart';
import 'package:suryaicons/twotone_rounded.dart';

class WsResponseTab extends ConsumerWidget {
  final String requestId;
  final ScrollController scrollController;

  const WsResponseTab({
    super.key,
    required this.requestId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wsRequestProvider(requestId));
    final messages = state.messages;

    if (messages.isEmpty) {
      return const Center(child: Text("No messages yet"));
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _MessageBubble(message: msg);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final WebSocketMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    // Arrow icon based on direction
    final icon = message.isSent
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final color = message.isSent ? Colors.blue : Colors.green;

    // return Card(
    //   margin: const EdgeInsets.symmetric(vertical: 4.0),
    //   child: ListTile(
    //     leading: Icon(icon, color: color),
    //     title: Text(message.message),
    //     subtitle: Text(
    //       DateFormat('HH:mm:ss.SSS').format(message.timestamp),
    //       style: const TextStyle(fontSize: 12),
    //     ),
    //     dense: true,
    //   ),
    // );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Icon(icon, color: color, size: 16),
          message.isSent
              ? const SuryaThemeIcon(
                  BulkRounded.arrowUpDouble,
                  clr: Color.fromARGB(255, 255, 168, 227),
                  size: 15,
                )
              : const SuryaThemeIcon(
                  BulkRounded.arrowDownDouble,
                  clr: Color.fromARGB(255, 0, 254, 30),
                  size: 14,
                ),
          SizedBox(width: 6),
          Expanded(
            child: Text(message.message, overflow: TextOverflow.ellipsis),
          ),
          Text(
            DateFormat('HH:mm:ss.SSS').format(message.timestamp),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

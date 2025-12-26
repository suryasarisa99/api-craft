import 'dart:convert';

import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';
import 'package:api_craft/features/request/providers/ws_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'package:xml/xml.dart';
import 'package:flutter/services.dart';

typedef WsMessageCallback = void Function(String? id, String? mssg);

class WsResponseTab extends ConsumerStatefulWidget {
  final String requestId;
  const WsResponseTab({super.key, required this.requestId});

  @override
  ConsumerState<WsResponseTab> createState() => _WsResponseTabState();
}

class _WsResponseTabState extends ConsumerState<WsResponseTab> {
  String? mssg;
  String? selectedId;
  final mssgsArea = Area(id: 1, min: 10, data: 'ws-messages');
  final detailArea = Area(id: 2, size: 200, data: 'ws-detail-mssg');
  final FocusNode _focusNode = FocusNode();

  late final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [mssgsArea],
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void showDetailArea(bool show) {
    _controller.areas = [mssgsArea, if (show) detailArea];
  }

  void _navigate(int direction) {
    final state = ref.read(wsRequestProvider(widget.requestId));
    final messages = state.messages;
    if (messages.isEmpty) return;

    int currentIndex = -1;
    if (selectedId != null) {
      currentIndex = messages.indexWhere((m) => m.id == selectedId);
    }

    int newIndex;
    if (currentIndex == -1) {
      if (direction > 0) {
        newIndex = 0;
      } else {
        newIndex = messages.length - 1;
      }
    } else {
      newIndex = currentIndex + direction;
    }

    if (newIndex >= 0 && newIndex < messages.length) {
      final msg = messages[newIndex];
      setState(() {
        selectedId = msg.id;
        mssg = msg.message;
      });
      showDetailArea(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.handled;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _navigate(-1);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _navigate(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MultiSplitView(
        axis: Axis.vertical,
        controller: _controller,
        builder: (context, area) {
          switch (area.data) {
            case 'ws-messages':
              return buildMessages();
            case 'ws-detail-mssg':
              if (mssg == null) {
                return const SizedBox.shrink();
              }
              return WsDetailMessage(mssg: mssg!);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget buildMessages() {
    final state = ref.watch(wsRequestProvider(widget.requestId));
    final messages = state.messages;

    if (messages.isEmpty) {
      return const Center(child: Text("No messages yet"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _MessageBubble(
          message: msg,
          onChanged: (id, v) {
            _focusNode.requestFocus();
            setState(() {
              selectedId = id;
              mssg = v;
            });
            showDetailArea(id != null);
          },
          selected: msg.id == selectedId,
        );
      },
    );
  }
}

class WsDetailMessage extends StatefulWidget {
  final String mssg;
  const WsDetailMessage({super.key, required this.mssg});

  @override
  State<WsDetailMessage> createState() => _WsDetailMessageState();
}

class _WsDetailMessageState extends State<WsDetailMessage> {
  late String textType = detectTextType(widget.mssg);

  String detectTextType(String input) {
    final text = input.trim();
    if (text.isEmpty) return "text";

    // JSON
    try {
      jsonDecode(text);
      return "json";
    } catch (e) {
      debugPrint("json error: $e");
    }

    // XML
    try {
      XmlDocument.parse(text);
      return "xml";
    } catch (_) {}

    return "text";
  }

  @override
  void didUpdateWidget(covariant WsDetailMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    textType = detectTextType(widget.mssg);
    debugPrint("textType: $textType");
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("textType: $textType");
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: [Text("Message Sent"), Spacer()]),
        ),
        SizedBox(height: 12),
        Expanded(
          child: CFCodeEditor(
            key: ValueKey(textType),
            text: widget.mssg,
            language: textType,
            readOnly: true,
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final WebSocketMessage message;
  final bool selected;
  final Function(String? id, String? mssg) onChanged;

  const _MessageBubble({
    required this.message,
    required this.onChanged,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    // Arrow icon based on direction
    // final icon = message.isSent
    //     ? Icons.arrow_upward_rounded
    //     : Icons.arrow_downward_rounded;
    // final color = message.isSent ? Colors.blue : Colors.green;

    final msg = message.message.replaceAll(RegExp(r'\s+'), ' ');
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        if (selected) {
          onChanged(null, null);
        } else {
          debugPrint("Selected message: ${message.id}");
          onChanged(message.id, message.message);
        }
      },
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? const Color.fromARGB(255, 59, 59, 59)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          children: [
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
              child: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(
              DateFormat('HH:mm:ss.SSS').format(message.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';

class HexViewer extends StatelessWidget {
  final Uint8List bytes;
  final ScrollController? scrollController;

  const HexViewer({super.key, required this.bytes, this.scrollController});

  @override
  Widget build(BuildContext context) {
    // Determine the number of rows needed (16 bytes per row)
    final int rows = (bytes.length / 16).ceil();
    final theme = Theme.of(context);
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: theme.colorScheme.onSurface,
    );
    final offsetStyle = style.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    final asciiStyle = style.copyWith(color: theme.colorScheme.secondary);

    return SelectionArea(
      child: ListView.builder(
        controller: scrollController,
        itemCount: rows,
        padding: const EdgeInsets.all(8.0),
        itemBuilder: (context, index) {
          final int start = index * 16;
          final int end = (start + 16 > bytes.length)
              ? bytes.length
              : start + 16;
          final sublist = bytes.sublist(start, end);

          // 1. Offset (8 characters, padded with 0)
          final offset = start.toRadixString(16).padLeft(8, '0').toUpperCase();

          // 2. Hex Bytes
          final List<Widget> hexWidgets = [];
          for (int i = 0; i < 16; i++) {
            if (i < sublist.length) {
              hexWidgets.add(
                SizedBox(
                  width: 20, // 2 chars (approx 8*2) + spacing
                  child: Text(
                    sublist[i].toRadixString(16).padLeft(2, '0').toUpperCase(),
                    style: style,
                  ),
                ),
              );
            } else {
              hexWidgets.add(const SizedBox(width: 24));
            }
            // Add extra spacing after each byte, and more after 8 bytes
            if (i == 7) {
              hexWidgets.add(const SizedBox(width: 12));
            } else {
              hexWidgets.add(const SizedBox(width: 3));
            }
          }

          // 3. ASCII representation
          // Replace non-printable characters with '.'
          final asciiBuffer = StringBuffer();
          for (final byte in sublist) {
            if (byte >= 32 && byte <= 126) {
              asciiBuffer.write(String.fromCharCode(byte));
            } else {
              asciiBuffer.write('.');
            }
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offset Column
              SizedBox(
                width: 75,
                child: Text(offset, textAlign: .justify, style: offsetStyle),
              ),
              const SizedBox(width: 12),
              // Hex Data Column
              Row(children: hexWidgets),
              const SizedBox(width: 12),
              // ASCII Column
              Expanded(child: Text(asciiBuffer.toString(), style: asciiStyle)),
            ],
          );
        },
      ),
    );
  }
}

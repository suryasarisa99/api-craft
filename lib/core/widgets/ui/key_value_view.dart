import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';

class KeyValueView extends StatelessWidget {
  final List<List<String>> items;
  final String pairSeparator;
  final String itemSeparator;
  final EdgeInsets padding;
  final TextStyle keyStyle;
  final TextStyle valueStyle;
  final int keyFlex;
  final int valueFlex;
  const KeyValueView({
    super.key,
    required this.items,
    required this.pairSeparator,
    required this.itemSeparator,
    this.padding = const EdgeInsets.all(8.0),
    required this.keyStyle,
    required this.valueStyle,
    this.keyFlex = 7,
    this.valueFlex = 13,
  });

  @override
  Widget build(BuildContext context) {
    // Optimization: If many items, SelectionArea around everything might be heavy?
    // User code had it.

    return Padding(
      padding: padding,
      child: SelectionArea(
        child: ExtendedText.rich(
          TextSpan(
            children: [
              for (final item in items)
                ExtendedWidgetSpan(
                  actualText:
                      "${item[0]}$pairSeparator${item[1]}$itemSeparator",
                  child: SelectionContainer.disabled(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: keyFlex,
                              child: Text(item[0], style: keyStyle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: valueFlex,
                              child: Text(item[1], style: valueStyle),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Divider(height: 1, thickness: 0.7),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

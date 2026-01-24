import 'package:api_craft/features/request/providers/req_compose_provider.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResponseHeaders extends ConsumerWidget {
  final String id;
  const ResponseHeaders({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(
      reqComposeProvider(id).select((d) => d.history?.firstOrNull?.headers),
    );
    if (headers == null) {
      return const Center(child: Text("No response headers"));
    }
    final headerClr = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: SelectionArea(
          child: ExtendedText.rich(
            TextSpan(
              children: [
                for (final header in headers)
                  ExtendedWidgetSpan(
                    actualText: "${header[0]}: ${header[1]}\n",
                    child: SelectionContainer.disabled(
                      child: Column(
                        children: [
                          SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: .start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Text(
                                  header[0],
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    // color: Color(0xFFD34399),
                                    color: headerClr,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 13,
                                child: Text(
                                  header[1],
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Divider(height: 1, thickness: 0.7),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KeyValueView extends StatelessWidget {
  final List<List<String>> items;
  final String pairSeparator;
  final String itemSeparator;
  final EdgeInsets padding;
  final TextStyle keyStyle;
  final TextStyle valueStyle;
  const KeyValueView({
    super.key,
    required this.items,
    required this.pairSeparator,
    required this.itemSeparator,
    this.padding = const EdgeInsets.all(8.0),
    required this.keyStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final headerClr = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
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
                        children: [
                          SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: .start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Text(
                                  item[0],
                                  // style: TextStyle(
                                  //   fontFamily: 'monospace',
                                  //   fontSize: 12,
                                  //   fontWeight: FontWeight.w500,
                                  //   // color: Color(0xFFD34399),
                                  //   color: headerClr,
                                  // ),
                                  style: keyStyle,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 13,
                                child: Text(
                                  item[1],
                                  // style: const TextStyle(
                                  //   fontFamily: 'monospace',
                                  //   fontSize: 12,
                                  //   fontWeight: FontWeight.w300,
                                  // ),
                                  style: valueStyle,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Divider(height: 1, thickness: 0.7),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

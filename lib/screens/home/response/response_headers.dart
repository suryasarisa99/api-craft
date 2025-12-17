import 'package:api_craft/providers/config_resolver_provider.dart';
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

    // return test2();
    // rich text + selectable
    return Container(
      // color: Colors.white,
      child: Padding(
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
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFD34399),
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
                  // TextSpan(
                  //   text: "${header[0]}: ${header[1]}\n",
                  //   style: const TextStyle(fontFamily: 'monospace'),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

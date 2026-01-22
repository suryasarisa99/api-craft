import 'package:api_craft/flows/flow_panel/selected_flow_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlowDetailURL extends ConsumerWidget {
  const FlowDetailURL({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (statusCode, url, path, method) = ref.watch(
      flowProvider.select((s) {
        return (
          s?.response?.statusCode,
          s?.request?.url ?? '',
          s?.request?.path ?? '',
          s?.request?.method ?? '',
        );
      }),
    );
    debugPrint('url: $url, p: $path');

    // final statusCode = ref.watch(
    //   provider.select((f) => f?.response?.statusCode),
    // );
    // final (path, scheme, method, host) = ref.watch(
    //   provider.select(
    //     (f) => (
    //       f?.request?.path ?? '',
    //       f?.request?.scheme ?? '',
    //       f?.request?.method ?? '',
    //       f?.request?.hostAndPort ?? '',
    //     ),
    //   ),
    // separate pathparameters and query parameters from path
    final pathParts = path.split('?');
    final pathWithoutQuery = pathParts[0];
    final queryParameters = pathParts.length > 1 ? '?${pathParts[1]}' : '';
    // final methodColor = getMethodColor(method);
    final methodColor = Colors.grey;
    return Container(
      padding: const .only(bottom: 10.0, top: 8),
      decoration: BoxDecoration(
        color: Color(0xff161819),
        border: Border(
          bottom: .new(color: Colors.grey[800]!, width: 0.5),
          // top: .new(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 8),
          Container(
            padding: const .symmetric(horizontal: 16.0, vertical: 3),
            decoration: BoxDecoration(
              // color: Colors.grey[800],
              color: methodColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text(
              method,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: methodColor,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          // status code
          if (statusCode != null)
            Container(
              padding: const .symmetric(horizontal: 22.0, vertical: 2.0),
              decoration: BoxDecoration(
                // color: getStatusCodeColor(statusCode).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                // "$statusCode ${getStatusCodeMessage(statusCode)}",
                statusCode.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Container(
              padding: const .symmetric(horizontal: 22.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 59, 41, 41),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Text(
                "Error",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),

          SizedBox(width: 8.0),

          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.white),
                children: [
                  // TextSpan(
                  //   text: '$scheme://',
                  //   style: const TextStyle(color: Colors.grey),
                  // ),
                  // TextSpan(
                  //   text: host,
                  //   style: const TextStyle(color: Color(0xFF3FA9FF)),
                  // ),
                  TextSpan(text: url),
                  // TextSpan(
                  //   text: pathWithoutQuery,
                  //   style: const TextStyle(color: Color(0xFF3ADA40)),
                  // ),
                  // if (queryParameters.isNotEmpty && queryParameters.length < 20)
                  //   TextSpan(
                  //     text: queryParameters,
                  //     style: const TextStyle(color: Colors.grey),
                  //   ),
                  // if (queryParameters.isNotEmpty &&
                  //     queryParameters.length >= 20)
                  //   TextSpan(
                  //     onEnter: (e) {},
                  //     text: '?...QueryParams',
                  //     style: const TextStyle(color: Colors.grey, fontSize: 12),
                  //   ),
                ],
              ),
            ),
          ),
          // IconButton(
          //   // icon: Icons.arrow_outward,
          //   icon: Icon(Icons.open_in_new, size: 18),
          //   // onPressed: onOpenInNewWindow,
          // ),
          SizedBox(width: 8.0),
        ],
      ),
    );
  }
}

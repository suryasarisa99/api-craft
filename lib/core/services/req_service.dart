import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/sidebar/file_tree_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReqService {
  // Getters
  static String? getUrl(Ref ref, String requestId) {
    final node = ref.read(fileTreeProvider).nodeMap[requestId];
    if (node is RequestNode) return node.url;
    return null;
  }

  static String? getMethod(Ref ref, String requestId) {
    final node = ref.read(fileTreeProvider).nodeMap[requestId];
    if (node is RequestNode) return node.method;
    return null;
  }

  static Map<String, String> getHeaders(Ref ref, String requestId) {
    final node = ref.read(fileTreeProvider).nodeMap[requestId];
    if (node is RequestNode) {
      // Return as Map for simple JS consumption
      final map = <String, String>{};
      for (final h in node.config.headers) {
        if (h.isEnabled) map[h.key] = h.value;
      }
      return map;
    }
    return {};
  }

  static String? getID(Ref ref) {
    return ref.read(activeReqIdProvider);
  }

  // Setters
  static void setUrl(Ref ref, String requestId, String url) {
    ref
        .read(fileTreeProvider.notifier)
        .updateUrl(requestId, url, persist: true);
  }

  static void setMethod(Ref ref, String requestId, String method) {
    ref
        .read(fileTreeProvider.notifier)
        .updateRequestMethod(requestId, method, persist: true);
  }
}

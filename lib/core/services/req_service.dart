import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/sidebar/file_tree_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReqService {
  static String? getUrl(Ref ref, String requestId) {
    final node = ref.read(fileTreeProvider).nodeMap[requestId];
    if (node == null || node is FolderNode) return null;
    return (node as RequestNode).url;
  }

  static String? getMethod(Ref ref, String requestId) {
    final node = ref.read(fileTreeProvider).nodeMap[requestId];
    if (node == null || node is FolderNode) return null;
    return (node as RequestNode).method;
  }

  //seters
  static void setUrl(Ref ref, String url) {
    final id = getID(ref);
    if (id == null) return;
    ref.read(reqComposeProvider(id).notifier).updateUrl(url);
  }

  static String? getID(Ref ref) {
    return ref.read(activeReqIdProvider);
  }
}

import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final activeReqProvider = NotifierProvider<ActiveReqNotifier, FileNode?>(
  ActiveReqNotifier.new,
);

class ActiveReqNotifier extends Notifier<FileNode?> {
  static const _prefKey = 'active_request_path';
  @override
  FileNode? build() {
    return getFromPrefs();
  }

  String? getDirectory() {
    final selectedNode = state;
    if (selectedNode == null) return null;
    return p.dirname(selectedNode.path);
  }

  bool isDirectoryOpen(String dirPath) {
    final node = state;
    if (node == null) return false;

    final normalizedDir = p.normalize(dirPath);
    final normalizedNode = p.normalize(node.path);

    return p.isWithin(normalizedDir, normalizedNode) ||
        normalizedDir == normalizedNode;
  }

  void setActiveNode(FileNode? node) {
    state = node;
    if (node != null) {
      prefs.setString(_prefKey, node.path);
    } else {
      prefs.remove(_prefKey);
    }
  }

  FileNode? getFromPrefs() {
    final path = prefs.getString(_prefKey);
    if (path == null) return null;
    return FileNode(path: path, name: p.basename(path), type: NodeType.request);
  }
}

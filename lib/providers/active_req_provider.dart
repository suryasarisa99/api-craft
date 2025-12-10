import 'dart:convert';

import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final activeReqProvider = NotifierProvider<ActiveReqNotifier, FileNode?>(
  ActiveReqNotifier.new,
);

class ActiveReqNotifier extends Notifier<FileNode?> {
  static const _prefKey = 'active_request_id';
  @override
  FileNode? build() {
    return getFromPrefs();
  }

  String? getDirectory() {
    final selectedNode = state;
    if (selectedNode == null) return null;
    return p.dirname(selectedNode.id);
  }

  // bool isDirectoryOpen(String dirPath) {
  //   final node = state;
  //   if (node == null) return false;

  //   final normalizedDir = p.normalize(dirPath);
  //   final normalizedNode = p.normalize(node.id);

  //   return p.isWithin(normalizedDir, normalizedNode) ||
  //       normalizedDir == normalizedNode;
  // }
  bool isAncestor(FileNode ancestorNode) {
    FileNode? current = state;
    while (current != null) {
      if (current.id == ancestorNode.id) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  void setActiveNode(FileNode? node) {
    state = node;
    if (node != null) {
      prefs.setString(_prefKey, jsonEncode(node.toMap()));
    } else {
      prefs.remove(_prefKey);
    }
  }

  FileNode? getFromPrefs() {
    final json = prefs.getString(_prefKey);
    if (json == null) return null;
    return FileNode.fromMap(jsonDecode(json));
    // return FileNode(id: id, name: p.basename(id), type: NodeType.request);
  }

  FileNode? _findNodeById(List<FileNode> nodes, String id) {
    for (var node in nodes) {
      if (node.id == id) return node;
      if (node.isDirectory && node.children != null) {
        final found = _findNodeById(node.children!, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// the stored node does not have references(reference to parent node)
  /// so when tree loads, we need to find the actual node in the tree
  void hydrateWithTree(List<FileNode> rootNodes) {
    final savedNode = getFromPrefs();
    if (savedNode == null) return;

    final foundNode = _findNodeById(rootNodes, savedNode.id);
    if (foundNode != null) {
      state = foundNode;
    } else {
      state = null;
    }
  }
}

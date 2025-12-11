import 'dart:convert';

import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final activeReqProvider = NotifierProvider<ActiveReqNotifier, Node?>(
  ActiveReqNotifier.new,
);

class ActiveReqNotifier extends Notifier<Node?> {
  static const _prefKey = 'active_request_id';
  @override
  Node? build() {
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
  bool isAncestor(Node ancestorNode) {
    Node? current = state;
    while (current != null) {
      if (current.id == ancestorNode.id) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  void setActiveNode(Node? node) {
    state = node;
    if (node != null) {
      final nodeMap = node.toMap();
      nodeMap.remove('headers');
      nodeMap.remove('body');
      debugPrint("Saving active request: ${node.name}: $nodeMap");
      prefs.setString(_prefKey, jsonEncode(nodeMap));
    } else {
      prefs.remove(_prefKey);
    }
  }

  Node? getFromPrefs() {
    final json = prefs.getString(_prefKey);
    if (json == null) return null;
    return Node.fromMap(jsonDecode(json));
    // return FileNode(id: id, name: p.basename(id), type: NodeType.request);
  }

  Node? _findNodeById(List<Node> nodes, String id) {
    for (var node in nodes) {
      if (node.id == id) return node;
      if (node is FolderNode && node.children.isNotEmpty) {
        final found = _findNodeById(node.children, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// the stored node does not have references(reference to parent node)
  /// so when tree loads, we need to find the actual node in the tree
  void hydrateWithTree(List<Node> rootNodes) {
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

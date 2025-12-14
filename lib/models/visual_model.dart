import 'package:flutter/foundation.dart';
import 'package:api_craft/models/models.dart'; // Import your Node classes

/// A lightweight view of a Node.
/// It ignores 'config', 'url', 'body', etc.
/// It only updates if the Structure (Name, Order, Type, Hierarchy) changes.
@immutable
class VisualNode {
  final String id;
  final String name;
  final NodeType type;
  final int sortOrder;
  final String? parentId;
  final String? method;
  final int? statusCode;
  final List<String> children; // Only IDs

  const VisualNode({
    required this.id,
    required this.method,
    required this.name,
    required this.statusCode,
    required this.type,
    required this.sortOrder,
    this.parentId,
    required this.children,
  });

  factory VisualNode.fromNode(Node node) {
    return VisualNode(
      id: node.id,
      name: node.name,
      type: node.type,
      statusCode: node is RequestNode ? node.statusCode : null,
      method: node is RequestNode ? node.method : null,
      sortOrder: node.sortOrder,
      parentId: node.parentId,
      children: node is FolderNode ? node.children : const [],
    );
  }

  // EQUALITY OVERRIDE: The Magic Performance Fix
  // We strictly IGNORE 'config', 'url', 'headers' here.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VisualNode &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.method == method &&
        other.parentId == parentId &&
        other.sortOrder == sortOrder &&
        listEquals(other.children, children); // Requires flutter/foundation
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    sortOrder,
    method,
    parentId,
    Object.hashAll(children),
  );
}

/// A wrapper for the Root List to force value equality check.
/// Without this, [ "a" ] != [ "a" ] in Dart, causing rebuilds.
@immutable
class RootList {
  final List<String> ids;
  const RootList(this.ids);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RootList && listEquals(other.ids, ids);
  }

  @override
  int get hashCode => Object.hashAll(ids);
}

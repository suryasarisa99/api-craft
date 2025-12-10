import 'package:path/path.dart' as p;

enum NodeType { folder, request }

enum DropSlot { top, center, bottom }

class FileNode {
  final String id; // Path (FileSystem) or UUID (Database)
  final String? parentId; // Parent Path (FileSystem) or Parent UUID (Database)
  final String name;
  final NodeType type;
  List<FileNode>? children; // For recursive tree building

  //The RAM-Only Reference
  FileNode? parent;

  FileNode({
    required this.id,
    required this.parentId,
    required this.name,
    required this.type,
    this.children,
  });

  bool get isDirectory => type == NodeType.folder;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'name': name,
      'type': type.toString(),
      // 'sort_order': 0, // Handled separately
    };
  }

  factory FileNode.fromMap(Map<String, dynamic> map) {
    return FileNode(
      id: map['id'],
      parentId: map['parent_id'],
      name: map['name'],
      type: map['type'] == 'NodeType.folder'
          ? NodeType.folder
          : NodeType.request,
    );
  }

  String get extension => p.extension(name);

  @override
  String toString() {
    return 'FileNode(name: $name, parentId: $parentId)';
  }
}

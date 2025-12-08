import 'package:path/path.dart' as p;

enum NodeType { folder, request }

enum DropSlot { top, center, bottom }

class FileNode {
  final String path;
  final String name;
  final NodeType type;
  final List<FileNode>? children; // Null if it's a file

  FileNode({
    required this.path,
    required this.name,
    required this.type,
    this.children,
  });

  // Helper to check if this node is a directory
  bool get isDirectory => type == NodeType.folder;

  // Formatting for display
  String get extension => p.extension(path);
}

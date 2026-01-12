import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/sidebar/file_tree_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ScriptType { preRequest, postRequest, test }

enum ScriptFlowStrategy {
  sandwich, // Pre: Top->Down, Post: Bottom->Up
  sequential, // Always Top->Down
  override, // Only the closest script runs
}

class ScriptExecutionService {
  final Ref ref;

  ScriptExecutionService(this.ref);

  /// Returns a list of scripts to execute for a specific request and type.
  List<String> getScriptsToRun(
    String requestId,
    ScriptType type, {
    ScriptFlowStrategy strategy = ScriptFlowStrategy.sandwich,
  }) {
    final tree = ref.read(fileTreeProvider);
    final map = tree.nodeMap;

    final lineage = <Node>[];
    String? currentId = requestId;

    // 1. Build lineage (Leaf -> Root)
    while (currentId != null) {
      final node = map[currentId];
      if (node != null) {
        lineage.add(node);
        currentId = node.parentId;
      } else {
        break;
      }
    }

    if (lineage.isEmpty) return [];

    // 2. Extract scripts based on type
    final scripts = <String>[];

    // Override Strategy: Only the first found script from Leaf -> Root
    if (strategy == ScriptFlowStrategy.override) {
      for (final node in lineage) {
        final script = _getScriptFromNode(node, type);
        if (script != null && script.isNotEmpty) {
          return [script];
        }
      }
      return [];
    }

    // Default Strategies (Sandwich / Sequential)

    // Lineage is [Request, Folder, Collection] (Leaf -> Root)

    if (strategy == ScriptFlowStrategy.sequential) {
      // Top -> Down (Root -> Leaf)
      for (final node in lineage.reversed) {
        final script = _getScriptFromNode(node, type);
        if (script != null && script.isNotEmpty) {
          scripts.add(script);
        }
      }
    } else {
      // Sandwich
      // Pre-Request: Top -> Down (Root -> Leaf)
      // Post/Test: Bottom -> Up (Leaf -> Root)

      if (type == ScriptType.preRequest) {
        // Top -> Down
        for (final node in lineage.reversed) {
          final script = _getScriptFromNode(node, type);
          if (script != null && script.isNotEmpty) {
            scripts.add(script);
          }
        }
      } else {
        // Post/Test: Bottom -> Up (Leaf -> Root)
        for (final node in lineage) {
          final script = _getScriptFromNode(node, type);
          if (script != null && script.isNotEmpty) {
            scripts.add(script);
          }
        }
      }
    }

    return scripts;
  }

  String? _getScriptFromNode(Node node, ScriptType type) {
    if (node is! RequestNode &&
        node is! FolderNode &&
        node is! CollectionNode) {
      return null;
    }

    // We already moved scripts to NodeConfig, so we can access them generally if we cast to Node<NodeConfig>
    // or just rely on the implementation details. Since NodeConfig is abstract but holds the fields:
    final config = node.config;

    switch (type) {
      case ScriptType.preRequest:
        return config.preRequestScript;
      case ScriptType.postRequest:
        return config.postRequestScript;
      case ScriptType.test:
        return config.testScript;
    }
  }
}

final scriptExecutionProvider = Provider((ref) => ScriptExecutionService(ref));

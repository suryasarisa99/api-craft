import 'package:api_craft/repository/storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'dart:convert';

import 'repository_provider.dart';

// final configResolverProvider = Provider((ref) => ConfigResolver(ref));

// class ConfigResolver {
//   final Ref ref;
//   ConfigResolver(this.ref);

//   Future<ResolvedConfig> resolveConfig(FileNode targetNode) async {
//     final repo = await ref.read(repositoryProvider.future);

//     // 1. Identify Ancestors (In Memory)
//     List<FileNode> ancestors = [];
//     FileNode? current = targetNode is FolderNode
//         ? targetNode
//         : targetNode.parent;

//     while (current != null) {
//       if (current is FolderNode) ancestors.add(current);
//       current = current.parent;
//     }

//     // 2. Walk Ancestors (Root -> Parent)
//     //    AND Lazy Load missing data on the fly
//     FolderConfig inheritedConfig = const FolderConfig();

//     for (var node in ancestors.reversed) {
//       // [THE FIX] Check if we need to load data?
//       if (!node.isDetailLoaded && node is FolderNode) {
//         await _hydrateNode(repo, node); // <--- Fetch from DB & Update RAM
//       }

//       // Now we are safe to read the properties
//       inheritedConfig = inheritedConfig.mergeWith(
//         FolderConfig(
//           headers: node.headers,
//           variables: (node as FolderNode).variables,
//           authData: node.auth,
//         ),
//       );
//     }

//     // 3. Prepare Local Config
//     FolderConfig localConfig = const FolderConfig();
//     if (targetNode is FolderNode) {
//       // If target is folder, ensure it's loaded too
//       if (!targetNode.isDetailLoaded) {
//         await _hydrateNode(repo, targetNode);
//       }
//       localConfig = FolderConfig(
//         headers: targetNode.headers,
//         variables: targetNode.variables,
//         authData: targetNode.auth,
//       );
//     }

//     return ResolvedConfig(inherited: inheritedConfig, local: localConfig);
//   }

//   /// Helper: Fetches DB data and mutates the Node in memory
//   Future<void> _hydrateNode(StorageRepository repo, FileNode node) async {
//     print("Lazy Loading Config for: ${node.name}"); // Debugging

//     // 1. Fetch from DB
//     // We cast to DbStorageRepository to access specific methods,
//     // or add 'getNodeDetails' to your abstract interface.
//     final details = await (repo as DbStorageRepository).getNodeDetails(node.id);

//     if (details.isEmpty) return;

//     // 2. Update the Node in Place (Mutation)
//     // Since 'headers' field is final, we unfortunately have to
//     // rely on your model structure.
//     // IDEALLY: The Map inside the node should be mutable.

//     if (details['headers'] != null) {
//       node.headers.addAll(
//         Map<String, String>.from(jsonDecode(details['headers'])),
//       );
//     }
//     if (details['auth'] != null) {
//       // node.auth is tricky if it's final.
//       // Better design: Make config container mutable or replaceable.
//       // For this example, let's assume auth is a Mutable Map or you have a setter.
//     }
//     if (node is FolderNode && details['variables'] != null) {
//       node.variables.addAll(
//         Map<String, String>.from(jsonDecode(details['variables'])),
//       );
//     }

//     // 3. Mark as Loaded so we never fetch again
//     node.isDetailLoaded = true;
//   }
// }

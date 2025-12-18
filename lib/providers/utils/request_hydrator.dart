import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/repository/storage_repository.dart';

import 'package:api_craft/template-functions/models/template_context.dart';

class RequestHydrator {
  final TemplateContext ref;
  RequestHydrator(this.ref);

  StorageRepository get _repo => ref.read(repositoryProvider);

  Future<void> hydrateNode(Node node) async {
    if (node.config.isDetailLoaded) return;

    final details = await _repo.getNodeDetails(node.id);
    if (details.isNotEmpty) {
      node.hydrate(details);
      ref.read(fileTreeProvider.notifier).updateNode(node);
    }
  }

  Future<void> hydrateAncestors(Node node) async {
    Node? ptr = _parentOf(node);
    while (ptr != null) {
      await hydrateNode(ptr);
      ptr = _parentOf(ptr);
    }
  }

  FolderNode? _parentOf(Node node) {
    return ref.read(fileTreeProvider).nodeMap[node.parentId] as FolderNode?;
  }
}

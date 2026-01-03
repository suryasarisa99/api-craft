import 'dart:async';
import 'package:api_craft/features/request/widgets/tabs/tab_titles.dart';
import 'package:api_craft/features/sidebar/providers/clipboard_provider.dart';

import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/features/folder/folder_config_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:api_craft/core/providers/providers.dart';
// {required FutureOr<Menu?> Function(MenuRequest) menuProvider}

import 'package:api_craft/features/request/services/http_service.dart';

FutureOr<Menu?> getMenuProvider({
  required WidgetRef ref,
  required BuildContext context,
  Node? node,
  bool isDirectory = false,
  bool isRoot = false,
}) async {
  return Menu(
    children: [
      if (isDirectory || isRoot)
        ..._getFolderSpecificMenuActions(
          ref: ref,
          context: context,
          node: node,
          isRoot: isRoot,
        )
      else
        ..._getFileSpecificMenuActions(ref: ref, context: context, node: node!),
      if (node != null) ..._getCommonMenuActions(ref, node, context),
    ],
  );
}

List<MenuElement> _getCommonMenuActions(
  WidgetRef ref,
  Node node,
  BuildContext context,
) {
  return [
    MenuAction(
      title: 'Run',
      // icon: Icons.play_arrow, // MenuAction might not support icon depending on pkg
      callback: () {
        ref.read(fileTreeProvider.notifier).runSelectedRequests(context);
      },
    ),
    MenuSeparator(),
    MenuAction(
      title: 'Copy',
      callback: () {
        final selected = ref.read(selectedNodesProvider);
        final nodesToCopy = selected.contains(node.id) ? selected : {node.id};
        ref.read(clipboardProvider.notifier).copy(nodesToCopy);
      },
    ),
    MenuAction(
      title: 'Cut',
      callback: () {
        final selected = ref.read(selectedNodesProvider);
        final nodesToCut = selected.contains(node.id) ? selected : {node.id};
        ref.read(clipboardProvider.notifier).cut(nodesToCut);
      },
    ),
    if (ref.watch(clipboardProvider).isNotEmpty)
      MenuAction(
        title: 'Paste',
        callback: () {
          final clipboard = ref.read(clipboardProvider);
          if (clipboard.isNotEmpty) {
            ref
                .read(fileTreeProvider.notifier)
                .paste(clipboard, targetId: node.id);
          }
        },
      ),
    MenuSeparator(),
    MenuAction(
      title: 'Duplicate',
      callback: () {
        ref.read(fileTreeProvider.notifier).duplicateNode(node);
      },
    ),
    MenuAction(
      title: 'Delete',
      callback: () {
        ref.read(fileTreeProvider.notifier).deleteSelectedNodes();
      },
    ),
  ];
}

// requires parent node
List<MenuElement> _getFolderSpecificMenuActions({
  required WidgetRef ref,
  required BuildContext context,
  required Node? node,
  bool isRoot = false,
}) {
  // final String? parentId = isRoot
  //     ? (await ref.read(selectedCollectionProvider.future))?.id
  //     : node?.id;
  final String? parentId = isRoot ? null : node?.id;
  debugPrint('Parent ID for context menu: $parentId, isRoot: $isRoot');
  final collectionId = (ref.read(selectedCollectionProvider))?.id;
  debugPrint('Collection ID for context menu: $collectionId');
  return [
    MenuSeparator(),
    MenuAction(
      title: 'HTTP Request',
      callback: () {
        createFile(
          context: context,
          ref: ref,
          isRoot: isRoot,
          parentId: parentId,
          type: RequestType.http,
        );
      },
    ),
    MenuAction(
      title: 'WebSocket Request',
      callback: () {
        createFile(
          context: context,
          ref: ref,
          isRoot: isRoot,
          parentId: parentId,
          type: RequestType.ws,
        );
      },
    ),
    MenuAction(
      title: 'GraphQL Request',
      callback: () {
        createFile(
          context: context,
          ref: ref,
          isRoot: isRoot,
          parentId: parentId,
          type: RequestType.http,
          bodyType: BodyType.graphql,
        );
      },
    ),
    MenuAction(
      title: 'New Folder',
      callback: () {
        createFolder(
          context: context,
          ref: ref,
          isRoot: isRoot,
          parentId: parentId,
        );
      },
    ),
    if (node != null && node is FolderNode)
      MenuAction(
        title: 'Configure Folder',
        callback: () async {
          showFolderConfigDialog(context: context, ref: ref, id: node.id);
        },
      ),
    if (ref.watch(clipboardProvider).isNotEmpty)
      MenuAction(
        title: 'Paste',
        callback: () {
          final clipboard = ref.read(clipboardProvider);
          if (clipboard.isNotEmpty) {
            ref
                .read(fileTreeProvider.notifier)
                .paste(clipboard, targetId: parentId);
          }
        },
      ),
  ];
}

void showFolderConfigDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String id,
  int? tabIndex,
}) {
  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return FolderConfigDialog(id: id, tabIndex: tabIndex);
    },
  );
}

// requires current node
List<MenuElement> _getFileSpecificMenuActions({
  required WidgetRef ref,
  required BuildContext context,
  required Node node,
}) {
  return [];
}

void createFolder({
  required BuildContext context,
  required WidgetRef ref,
  bool useSelectedNode = false,
  String? parentId,
  required bool isRoot,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return InputDialog(
        title: "New Folder",
        placeholder: "Folder Name",
        onConfirmed: (folderName) {
          final folder = useSelectedNode
              ? ref.read(activeReqProvider)?.parentId
              : parentId;
          ref
              .read(fileTreeProvider.notifier)
              .createItem(folder, folderName, NodeType.folder);
        },
      );
    },
  );
}

void createFile({
  required BuildContext context,
  required WidgetRef ref,
  required bool isRoot,
  bool useSelectedNode = false,
  String? parentId,
  String? bodyType,
  RequestType type = RequestType.http,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return InputDialog(
        title: bodyType == "GraphQL"
            ? "New GraphQL Request"
            : type == RequestType.http
            ? "New HTTP Request"
            : "New WebSocket Request",
        placeholder: "File Name",
        onConfirmed: (fileName) {
          final folder = useSelectedNode
              ? ref.read(activeReqProvider)?.parentId
              : parentId;
          ref
              .read(fileTreeProvider.notifier)
              .createItem(
                folder,
                fileName,
                NodeType.request,
                requestType: type,
                bodyType: bodyType,
              );
        },
      );
    },
  );
}

import 'dart:async';

import 'package:api_craft/dialog/input_dialog.dart';
import 'package:api_craft/models/node_model.dart';
import 'package:api_craft/screens/home/folder/folder_config_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:api_craft/providers/providers.dart';
// {required FutureOr<Menu?> Function(MenuRequest) menuProvider}

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
        ...await _getFolderSpecificMenuActions(
          ref: ref,
          context: context,
          node: node,
          isRoot: isRoot,
        )
      else
        ..._getFileSpecificMenuActions(ref: ref, context: context, node: node!),
      if (node != null) ..._getCommonMenuActions(ref, node),
    ],
  );
}

// requires current node
List<MenuElement> _getCommonMenuActions(WidgetRef ref, Node node) {
  return [
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
        ref.read(fileTreeProvider.notifier).deleteNode(node);
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
      title: 'New File',
      callback: () {
        createFile(
          context: context,
          ref: ref,
          isRoot: isRoot,
          parentId: parentId,
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
          showFolderConfigDialog(context: context, ref: ref, node: node);
        },
      ),
  ];
}

void showFolderConfigDialog({
  required BuildContext context,
  required WidgetRef ref,
  required FolderNode node,
}) {
  final repo = ref.read(repositoryProvider);
  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return FolderConfigDialog(
        node: node,
        onSave: (s) {
          repo.updateNode(node);
        },
      );
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
              ? ref.read(activeReqProvider.notifier).getDirectory()
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
}) {
  showDialog(
    context: context,
    builder: (context) {
      return InputDialog(
        title: "New Request File",
        placeholder: "File Name",
        onConfirmed: (fileName) {
          final folder = useSelectedNode
              ? ref.read(activeReqProvider.notifier).getDirectory()
              : parentId;
          ref
              .read(fileTreeProvider.notifier)
              .createItem(folder, fileName, NodeType.request);
        },
      );
    },
  );
}

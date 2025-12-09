import 'dart:async';

import 'package:api_craft/dialog/input_dialog.dart';
import 'package:api_craft/models/file_system_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:api_craft/providers/providers.dart';
// {required FutureOr<Menu?> Function(MenuRequest) menuProvider}

FutureOr<Menu?> getMenuProvider({
  required WidgetRef ref,
  required BuildContext context,
  FileNode? node,
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
        )
      else
        ..._getFileSpecificMenuActions(ref: ref, context: context, node: node!),
      if (node != null) ..._getCommonMenuActions(ref, node),
    ],
  );
}

// requires current node
List<MenuElement> _getCommonMenuActions(WidgetRef ref, FileNode node) {
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
Future<List<MenuElement>> _getFolderSpecificMenuActions({
  required WidgetRef ref,
  required BuildContext context,
  required FileNode? node,
  bool isRoot = false,
}) async {
  final FileNode? parentNode = isRoot ? null : node;
  return [
    MenuSeparator(),
    MenuAction(
      title: 'New File',
      callback: () {
        createFile(
          context: context,
          ref: ref,
          isRoot: isRoot,
          parentNode: parentNode,
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
          parentNode: parentNode,
        );
      },
    ),
  ];
}

// requires current node
List<MenuElement> _getFileSpecificMenuActions({
  required WidgetRef ref,
  required BuildContext context,
  required FileNode node,
}) {
  return [];
}

void createFolder({
  required BuildContext context,
  required WidgetRef ref,
  bool useSelectedNode = false,
  FileNode? parentNode,
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
              : parentNode?.path;
          ref.read(fileTreeProvider.notifier).createFolder(folder, folderName);
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
  FileNode? parentNode,
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
              : parentNode?.path;
          ref.read(fileTreeProvider.notifier).createRequest(folder, fileName);
        },
      );
    },
  );
}

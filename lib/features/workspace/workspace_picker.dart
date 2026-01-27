import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/toast_service.dart';

import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'package:api_craft/features/workspace/workspace_config_dialog.dart';
import 'package:file_picker/file_picker.dart';

class WorkspacePicker extends ConsumerStatefulWidget {
  const WorkspacePicker({super.key});

  @override
  ConsumerState<WorkspacePicker> createState() => _WorkspacePickerState();
}

class _WorkspacePickerState extends ConsumerState<WorkspacePicker> {
  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();

  @override
  Widget build(BuildContext context) {
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
    final workspaces = ref.watch(workspacesProvider).asData?.value ?? [];

    return MyCustomMenu.contentColumn(
      popupKey: _popupKey,
      width: 200,
      items: [
        ...workspaces.map((c) {
          final isSelected = c.id == selectedWorkspace?.id;
          return CustomMenuIconItem.tick(
            title: Text(c.name),
            value: c.id,
            checked: isSelected,
            onTap: (_) {
              ref.read(selectedWorkspaceProvider.notifier).select(c);
              // change active request
              // ref.read(activeReqIdProvider.notifier).setActiveId(null);
            },
          );
        }),
        menuDivider,
        CustomMenuIconItem(
          icon: const SuryaThemeIcon(BulkRounded.plusSign),
          title: const Text("Create New..."),
          value: 'create',
          onTap: (_) => _showCreateDialog(context),
        ),

        if (selectedWorkspace != null) ...[
          menuDivider,
          CustomMenuIconItem(
            icon: const SuryaThemeIcon(BulkRounded.settings01),
            title: const Text("Configure Workspace"),
            value: 'configure',
            onTap: (_) {
              showDialog(
                context: context,
                builder: (_) =>
                    WorkspaceConfigDialog(workspaceId: selectedWorkspace.id),
              );
            },
          ),
          menuDivider,
          CustomMenuIconItem(
            icon: const SuryaThemeIcon(BulkRounded.linkBackward),
            title: const Text("Clear History"),
            value: 'clear_history',
            onTap: (_) {
              ref.read(dataRepositoryProvider).clearHistoryForWorkspace();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("History cleared")));
            },
          ),
        ],
        if (selectedWorkspace != null &&
            selectedWorkspace.id != kDefaultWorkspace.id)
          CustomMenuIconItem(
            icon: const SuryaThemeIcon(BulkRounded.delete01),
            title: const Text(
              "Delete Workspace",
              style: TextStyle(color: Colors.red),
            ),
            value: 'delete',
            onTap: (_) => _showDeleteDialog(context, selectedWorkspace),
          ),
      ],
      child: Text(
        selectedWorkspace != null ? selectedWorkspace.name : 'Select Workspace',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateWorkspaceDialog(),
    );
  }

  void _showDeleteDialog(BuildContext context, WorkspaceModel workspace) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete '${workspace.name}'?"),
        content: const Text(
          "This will permanently delete this workspace and all its requests, history, and environments.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(workspacesProvider.notifier)
                  .deleteWorkspace(workspace.id);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

class _CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  ConsumerState<_CreateWorkspaceDialog> createState() =>
      _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState
    extends ConsumerState<_CreateWorkspaceDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedPath;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _selectedPath = result;
      });
    }
  }

  Future<void> _create() async {
    try {
      final name = _nameController.text.trim();
      if (name.isEmpty) return;

      final type = _selectedPath != null
          ? WorkspaceType.filesystem
          : WorkspaceType.database;

      final newWorkspace = await ref
          .read(workspacesProvider.notifier)
          .createWorkspace(name, type: type, path: _selectedPath);

      if (mounted) {
        ref.read(selectedWorkspaceProvider.notifier).select(newWorkspace);
        Navigator.pop(context);
      }
    } catch (e) {
      ToastService.error(
        "Workspace creation failed",
        description: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text("New Workspace"),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Workspace Name",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 16),
            const Text(
              "Storage Loaction",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                dense: true,
                onTap: _pickFolder,
                leading: const Icon(Icons.folder, size: 20),
                title: Text(
                  _selectedPath ?? "Database (Default)",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _selectedPath == null
                        ? theme.disabledColor
                        : theme.textTheme.bodyMedium?.color,
                    fontStyle: _selectedPath == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                trailing: _selectedPath != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _selectedPath = null;
                          });
                        },
                      )
                    : const Icon(Icons.edit, size: 16),
              ),
            ),
            if (_selectedPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Files will be stored in this directory.",
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(onPressed: _create, child: const Text("Create")),
      ],
    );
  }
}

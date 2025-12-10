import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/repository/storage_repository.dart';
import 'package:api_craft/widgets/tabs/headers_tab.dart';
import 'package:api_craft/screens/home/folder/folder_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FolderConfigDialog extends ConsumerStatefulWidget {
  final FolderNode node;
  final Function(FolderNode) onSave;

  const FolderConfigDialog({
    super.key,
    required this.node,
    required this.onSave,
  });

  @override
  ConsumerState<FolderConfigDialog> createState() => _FolderConfigDialogState();
}

class _FolderConfigDialogState extends ConsumerState<FolderConfigDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FolderEditorController _controller;
  late Future<StorageRepository> _repoFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _repoFuture = ref.read(repositoryProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    // return AnimatedBuilder(
    //   animation: _controller,
    //   builder: (context, _) {
    //     return ;
    //   },
    // );
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 900,
        height: 700,
        child: FutureBuilder(
          future: _repoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            _controller = FolderEditorController(
              node: widget.node,
              repo: snapshot.data!,
              onSaveToRepo: (updatedNode) {
                widget.onSave(updatedNode);
              },
            );
            return _buildDialog();
          },
        ),
      ),
    );
  }

  Widget _buildDialog() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 28, color: Colors.grey),
              const SizedBox(width: 12),
              Text(
                _controller.node.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "General"),
              Tab(text: "Headers"),
              Tab(text: "Authorization"),
              Tab(text: "Variables"),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. General Tab
              _buildGeneralTab(),
              // 2. Headers Tab
              HeadersTab(controller: _controller),
              // 3. Auth Tab
              _AuthTab(controller: _controller),
              _AuthTab(controller: _controller),
              // 4. Variables Tab
              // _VariablesTab(controller: _controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextFormField(
          initialValue: _controller.node.name,
          decoration: const InputDecoration(
            labelText: "Folder Name",
            border: OutlineInputBorder(),
          ),
          onChanged: _controller.updateName,
        ),
        const SizedBox(height: 24),
        TextFormField(
          initialValue: _controller.node.config.description,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: "Description",
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            // Add description update logic to controller similar to updateName
          },
        ),
      ],
    );
  }
}

// --- AUTH TAB ---
class _AuthTab extends StatelessWidget {
  final FolderEditorController controller;
  const _AuthTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final auth = controller.node.config.auth;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<AuthType>(
            decoration: const InputDecoration(
              labelText: "Auth Type",
              border: OutlineInputBorder(),
            ),
            initialValue: auth.type,
            items: AuthType.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (type) {
              if (type != null) {
                controller.updateAuth(auth.copyWith(type: type));
              }
            },
          ),
        ),
        if (auth.type == AuthType.inherit)
          Expanded(
            child: Center(
              child: Text(
                "Inheriting ${controller.effectiveAuth.type.name} from ${controller.effectiveAuthSource}",
              ),
            ),
          )
        else if (auth.type == AuthType.noAuth)
          const Expanded(child: Center(child: Text("No Authentication")))
        else
          // Show fields for Basic/Bearer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (auth.type == AuthType.bearer)
                  TextFormField(
                    initialValue: auth.token,
                    decoration: const InputDecoration(labelText: "Token"),
                    onChanged: (v) =>
                        controller.updateAuth(auth.copyWith(token: v)),
                  ),
                // Add Basic Auth fields...
              ],
            ),
          ),
      ],
    );
  }
}

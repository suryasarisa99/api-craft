import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/utils/debouncer.dart';
import 'package:api_craft/widgets/tabs/auth_tab.dart';
import 'package:api_craft/widgets/tabs/environment_tab.dart';
import 'package:api_craft/widgets/tabs/headers_tab.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FolderConfigDialog extends ConsumerStatefulWidget {
  final String id;

  const FolderConfigDialog({super.key, required this.id});

  @override
  ConsumerState<FolderConfigDialog> createState() => _FolderConfigDialogState();
}

class _FolderConfigDialogState extends ConsumerState<FolderConfigDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ResolveConfigNotifier resolveConfigProviderNotifier;
  late final notifier = ref.read(resolveConfigProvider(widget.id).notifier);
  final debouncer = Debouncer(Duration(milliseconds: 1000));
  static const useLazyMode = true;
  bool hasChanges = true;
  late final ProviderSubscription<Node> subscription;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    subscription = ref.listenManual(
      resolveConfigProvider(widget.id).select((d) => d.node),
      (_, n) {
        debugPrint(
          "folder-dialog:: detected node change: ${n.name}, headers len: ${n.config.headers.length}",
        );
        debugPrint("headers are: ${n.config.headers}");
        if (useLazyMode) {
          /// note: hasChanges is always becomes true, when folder config dialog is opened
          hasChanges = true;
          subscription.close();
        } else {
          debouncer.run(() {
            ref.read(repositoryProvider).updateNode(n);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    debugPrint("Disposing FolderConfigDialog for node ${widget.id}");
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (pop, result) async {
        debugPrint("set last updated folder for node ${widget.id}");
        ref
            .read(nodeUpdateTriggerProvider.notifier)
            .setLastUpdatedFolder(widget.id);
        debugPrint("Popping FolderConfigDialog for node ${widget.id}");
        if (useLazyMode && hasChanges) {
          final currentState = ref.read(resolveConfigProvider(widget.id));
          ref.read(repositoryProvider).updateNode(currentState.node);
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(width: 900, height: 700, child: _buildDialog()),
      ),
    );
  }

  Widget _buildDialog() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        // Header
        Consumer(
          builder: (context, ref, child) {
            final title = ref.watch(
              resolveConfigProvider(
                widget.id,
              ).select((value) => value.node.name),
            );
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 28, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            );
          },
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
              _GeneralTab(id: widget.id),
              // 2. Headers Tab
              HeadersTab(id: widget.id),
              // 3. Auth Tab
              AuthTab(id: widget.id),
              EnvironmentTab(id: widget.id),
              // 4. Variables Tab
              // _VariablesTab(controller: _controller),
            ],
          ),
        ),
      ],
    );
  }
}

class _GeneralTab extends ConsumerStatefulWidget {
  final String id;
  const _GeneralTab({required this.id});

  ResolveConfigNotifier notifier(WidgetRef ref) =>
      ref.read(resolveConfigProvider(id).notifier);
  @override
  ConsumerState<_GeneralTab> createState() => __GeneralTabState();
}

class __GeneralTabState extends ConsumerState<_GeneralTab> {
  late final provider = resolveConfigProvider(widget.id);
  // for description  this value is null sometimes, due to lazyload of config
  // thats we we use listener to update text controller
  late final descriptionController = TextEditingController(
    text: ref.read(provider.select((value) => value.node.config.description)),
  );
  late final String name = ref.read(
    provider.select((value) => value.node.name),
  );

  late final ResolveConfigNotifier notifier = ref.read(
    resolveConfigProvider(widget.id).notifier,
  );

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("building::: General Tab");
    ref.listen(provider.select((value) => value.node.config.description), (
      _,
      n,
    ) {
      descriptionController.text = n;
      // update text controller value when it has empty
      if (n.isNotEmpty && descriptionController.text.isEmpty) {
        descriptionController.text = n;
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          TextFormField(
            initialValue: name,
            decoration: const InputDecoration(
              labelText: "Folder Name",
              border: OutlineInputBorder(),
            ),
            onChanged: notifier.updateName,
          ),
          const SizedBox(height: 24),
          TextFormField(
            // initialValue: description,
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: "Description",
              border: OutlineInputBorder(),
            ),
            onChanged: notifier.updateDescription,
          ),
        ],
      ),
    );
  }
}

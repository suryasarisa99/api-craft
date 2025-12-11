import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/sidebar/context_menu.dart';
import 'package:api_craft/utils/debouncer.dart';
import 'package:api_craft/widgets/tabs/evironment_tab.dart';
import 'package:api_craft/widgets/tabs/headers_tab.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FolderConfigDialog extends ConsumerStatefulWidget {
  final FolderNode node;
  final Function(Node) onSave;

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
  late final ResolveConfigNotifier resolveConfigProviderNotifier;
  late final EditorParams _editorParams = EditorParams(widget.node);
  late final notifier = ref.read(resolveConfigProvider(_editorParams).notifier);
  final debouncer = DebouncerFlush(Duration(milliseconds: 1000));
  static const useLazyMode = true;
  bool hasChanges = false;
  late final ProviderSubscription<ResolveConfig> subscription;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    subscription = ref.listenManual(
      resolveConfigProvider(_editorParams).select((data) => data),
      (_, n) {
        if (useLazyMode) {
          /// note: hasChanges is always becomes true, when folder config dialog is opened
          hasChanges = true;
          subscription.close();
        } else {
          debouncer.run(() {
            widget.onSave(n.node);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    debugPrint("Disposing FolderConfigDialog for node ${widget.node.name}");
    // if (useLazyMode && hasChanges) {
    //   final currentState = ref.read(resolveConfigProvider(_editorParams));
    //   widget.onSave(currentState.node);
    // }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (pop, result) async {
        debugPrint("Popping FolderConfigDialog for node ${widget.node.name}");
        if (useLazyMode && hasChanges) {
          final currentState = ref.read(resolveConfigProvider(_editorParams));
          widget.onSave(currentState.node);
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
                _editorParams,
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
              _GeneralTab(params: _editorParams),
              // 2. Headers Tab
              HeadersTab(params: _editorParams),
              // 3. Auth Tab
              _AuthTab(params: _editorParams),
              EnvironmentTab(params: _editorParams),
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
  final EditorParams params;
  const _GeneralTab({required this.params});

  ResolveConfigNotifier notifier(WidgetRef ref) =>
      ref.read(resolveConfigProvider(params).notifier);
  @override
  ConsumerState<_GeneralTab> createState() => __GeneralTabState();
}

class __GeneralTabState extends ConsumerState<_GeneralTab> {
  late final provider = resolveConfigProvider(widget.params);
  late final descriptionController = TextEditingController(
    text: ref.read(provider.select((value) => value.node.config.description)),
  );
  late final String name = ref.read(
    provider.select((value) => value.node.name),
  );

  late final ResolveConfigNotifier notifier = ref.read(
    resolveConfigProvider(widget.params).notifier,
  );
  late final debounce1 = DebouncerFlush(Duration(milliseconds: 1000));
  late final debounce2 = DebouncerFlush(Duration(milliseconds: 1000));

  @override
  void deactivate() {
    debounce1.flush();
    debounce2.flush();
    super.deactivate();
  }

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
            // onChanged: (name) => debounce1.run(() {
            //   notifier.updateName(name);
            // }),
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
            // onChanged: (description) => debounce2.run(() {
            //   notifier.updateDescription(description);
            // }),
            onChanged: notifier.updateDescription,
          ),
        ],
      ),
    );
  }
}

// --- AUTH TAB ---
class _AuthTab extends ConsumerWidget {
  final EditorParams params;
  const _AuthTab({required this.params});

  ResolveConfigNotifier notifier(WidgetRef ref) =>
      ref.read(resolveConfigProvider(params).notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(
      resolveConfigProvider(params).select((value) => value.node.config.auth),
    );
    final authSource = ref.watch(
      resolveConfigProvider(
        params,
      ).select((value) => value.effectiveAuthSource),
    );
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
                notifier(ref).updateAuth(auth.copyWith(type: type));
              }
            },
          ),
        ),
        if (auth.type == AuthType.inherit)
          Expanded(
            child: Center(
              child: Row(
                children: [
                  Text("auth type:  ${auth.type.name} from $authSource"),
                  const SizedBox(width: 8),
                  if (authSource != null)
                    TextButton(
                      onPressed: () {
                        if (params.node is FolderNode) {
                          // aldready we opened folder dialog
                          // so close it first
                          Navigator.of(context).pop();
                        }
                        showFolderConfigDialog(
                          context: context,
                          ref: ref,
                          node: authSource as FolderNode,
                        );
                      },
                      child: Text(authSource.name),
                    ),
                ],
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
                        notifier(ref).updateAuth(auth.copyWith(token: v)),
                  ),
                // Add Basic Auth fields...
              ],
            ),
          ),
      ],
    );
  }
}

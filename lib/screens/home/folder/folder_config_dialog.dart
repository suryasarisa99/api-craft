import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/utils/debouncer.dart';
import 'package:api_craft/widgets/tabs/auth_tab.dart';
import 'package:api_craft/widgets/tabs/environment_tab.dart';
import 'package:api_craft/widgets/tabs/headers_tab.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

class FolderConfigDialog extends ConsumerStatefulWidget {
  final String id;
  final int? tabIndex;
  const FolderConfigDialog({super.key, required this.id, this.tabIndex});

  @override
  ConsumerState<FolderConfigDialog> createState() => _FolderConfigDialogState();
}

class _FolderConfigDialogState extends ConsumerState<FolderConfigDialog> {
  late final ReqComposeNotifier resolveConfigProviderNotifier;
  late final notifier = ref.read(reqComposeProvider(widget.id).notifier);
  final debouncer = Debouncer(Duration(milliseconds: 1000));
  static const useLazyMode = true;
  bool hasChanges = true;
  late final ProviderSubscription<Node> subscription;
  late var tabIndex = widget.tabIndex ?? 0;

  @override
  void initState() {
    super.initState();
    subscription = ref.listenManual(
      reqComposeProvider(widget.id).select((d) => d.node),
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
          final currentState = ref.read(reqComposeProvider(widget.id));
          ref.read(repositoryProvider).updateNode(currentState.node);
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3D3D3D)),
          ),
          width: 900,
          height: 600,
          child: _buildDialog(),
        ),
      ),
    );
  }

  Widget _buildDialog() {
    final tabs = ["General", "Headers", "Auth", "Environment"];
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          // Header
          Consumer(
            builder: (context, ref, child) {
              final title = ref.watch(
                reqComposeProvider(
                  widget.id,
                ).select((value) => value.node.name),
              );
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 28, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              );
            },
          ),
          // SizedBox(
          //   height: 36,
          //   child: TabBar(
          //     controller: _tabController,
          //     labelColor: Colors.blue,
          //     unselectedLabelColor: Colors.grey,
          //     tabs: const [
          //       Tab(text: "General"),
          //       Tab(text: "Headers"),
          //       Tab(text: "Authorization"),
          //       Tab(text: "Variables"),
          //     ],
          //   ),
          // ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  child: Column(
                    children: [
                      for (final (index, tab) in tabs.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              setState(() {
                                tabIndex = index;
                              });
                            },
                            child: Container(
                              width: 150,
                              decoration: BoxDecoration(
                                color: tabIndex == index
                                    ? const Color(
                                        0xFFEC21F3,
                                      ).withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: index == 2 ? 0 : 6,
                                horizontal: 8,
                              ),

                              child: index == 2
                                  ? SizedBox(
                                      height: 32,
                                      child: AuthTabHeader(
                                        color: tabIndex == index
                                            ? const Color(0xFFE17FF0)
                                            : Colors.grey,
                                        widget.id,
                                        isTabActive: tabIndex == index,
                                        handleSetTab: () {
                                          setState(() {
                                            tabIndex = index;
                                          });
                                        },
                                      ),
                                    )
                                  : Text(
                                      tab,
                                      style: TextStyle(
                                        color: tabIndex == index
                                            ? const Color(0xFFE17FF0)
                                            : Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // child: TabBarView(
                  //   controller: _tabController,
                  //   children: ,
                  // ),
                  child: LazyLoadIndexedStack(
                    index: tabIndex,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralTab extends ConsumerStatefulWidget {
  final String id;
  const _GeneralTab({required this.id});

  ReqComposeNotifier notifier(WidgetRef ref) =>
      ref.read(reqComposeProvider(id).notifier);
  @override
  ConsumerState<_GeneralTab> createState() => __GeneralTabState();
}

class __GeneralTabState extends ConsumerState<_GeneralTab> {
  late final provider = reqComposeProvider(widget.id);
  // for description  this value is null sometimes, due to lazyload of config
  // thats we we use listener to update text controller
  late final descriptionController = TextEditingController(
    text: ref.read(provider.select((value) => value.node.config.description)),
  );
  late final String name = ref.read(
    provider.select((value) => value.node.name),
  );

  late final ReqComposeNotifier notifier = ref.read(
    reqComposeProvider(widget.id).notifier,
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.multiline,
              textAlign: TextAlign.start,
              textAlignVertical: TextAlignVertical.top,
              // initialValue: description,
              controller: descriptionController,
              expands: true,
              maxLines: null,
              minLines: null,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              onChanged: notifier.updateDescription,
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

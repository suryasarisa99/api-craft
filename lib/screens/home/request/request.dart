import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/utils/debouncer.dart';
import 'package:api_craft/widgets/tabs/auth_tab.dart';
import 'package:api_craft/widgets/tabs/headers_tab.dart';
import 'package:api_craft/widgets/ui/variable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReqTabWrapper extends ConsumerWidget {
  const ReqTabWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    late final activeNode = ref.watch(activeReqProvider);
    if (activeNode == null) {
      return const Center(child: Text("No active request"));
    }
    return RequestTab(key: ValueKey(activeNode.id), EditorParams(activeNode));
  }
}

class RequestTab extends ConsumerStatefulWidget {
  final EditorParams params;
  const RequestTab(this.params, {super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _RequestTabState();
}

class _RequestTabState extends ConsumerState<RequestTab>
    with SingleTickerProviderStateMixin {
  /// tabs
  late final List<Widget> children = [
    Center(child: Text("Body Tab")),
    Center(child: Text("Params Tab")),
    HeadersTab(params: widget.params),
    AuthTab(params: widget.params),
  ];

  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  late final _provider = resolveConfigProvider(widget.params);
  late final _repo = ref.read(repositoryProvider);
  final debouncer = DebouncerFlush(Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing Request Tab for ${widget.params.node.name}");
    ref.listenManual(_provider.select((d) => d.node), (_, v) {
      debouncer.run(() {
        debugPrint("req-tab:: ${v} ");
        _repo.updateNode(v);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("building::: Request Tab");

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          VariableTextField(),
          SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: "Body"),
                Tab(text: "Params"),
                Consumer(
                  builder: (context, ref, child) {
                    final headersCount = ref.watch(
                      _provider.select(
                        (value) =>
                            value.node.config.headers.length +
                            (value.inheritedHeaders?.length ?? 0),
                      ),
                    );
                    return Tab(text: "Headers ($headersCount)");
                  },
                ),
                AuthTapHeader(widget.params),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(controller: _tabController, children: children),
          ),
        ],
      ),
    );
  }
}

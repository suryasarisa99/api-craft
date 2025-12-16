import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/request/request_url.dart';
import 'package:api_craft/utils/debouncer.dart';
import 'package:api_craft/template-functions/widget/form_popup_widget.dart';
import 'package:api_craft/widgets/tabs/auth_tab.dart';
import 'package:api_craft/widgets/tabs/headers_tab.dart';
import 'package:api_craft/widgets/tabs/query_params.dart';
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
    return RequestTab(key: ValueKey(activeNode.id), activeNode);
  }
}

class RequestTab extends ConsumerStatefulWidget {
  final RequestNode node;
  const RequestTab(this.node, {super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _RequestTabState();
}

class _RequestTabState extends ConsumerState<RequestTab>
    with SingleTickerProviderStateMixin {
  /// tabs
  late final List<Widget> children = [
    Center(child: Text("Body Tab")),
    QueryParamsTab(id: widget.node.id),
    HeadersTab(id: widget.node.id),
    AuthTab(id: widget.node.id),
  ];

  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  late final _provider = reqComposeProvider(widget.node.id);
  late final _repo = ref.read(repositoryProvider);
  final debouncer = DebouncerFlush(Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing Request Tab for ${widget.node.name}");
    ref.listenManual(_provider.select((d) => d.node), (_, v) {
      debouncer.run(() {
        debugPrint("req-tab:: debounce ${v.name} ");
        _repo.updateNode(v);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("building::: Request Tab");

    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        children: [
          RequestUrl(id: widget.node.id),
          SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: TabBar(
              dividerColor: Colors.transparent,
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              tabs: [
                Tab(text: "Body"),
                Consumer(
                  builder: (context, ref, child) {
                    final paramsCount = ref.watch(
                      _provider.select(
                        (value) => (value.node as RequestNode)
                            .config
                            .queryParameters
                            .length,
                      ),
                    );
                    return Tab(
                      text: "Params${paramsCount > 0 ? ' ($paramsCount)' : ''}",
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final headersCount = ref.watch(
                      _provider.select(
                        (value) =>
                            value.node.config.headers.length +
                            (value.inheritedHeaders?.length ?? 0),
                      ),
                    );
                    return Tab(
                      text:
                          "Headers${headersCount > 0 ? ' ($headersCount)' : ''}",
                    );
                  },
                ),
                AuthTabHeader(widget.node.id, controller: _tabController),
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

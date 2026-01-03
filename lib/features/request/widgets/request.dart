import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/request/widgets/request_url.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/features/auth/auth_tab.dart';
import 'package:api_craft/features/request/widgets/tabs/headers_tab.dart';
import 'package:api_craft/features/request/widgets/tabs/query_params.dart';
import 'package:api_craft/features/request/widgets/tabs/body_tab.dart';
import 'package:api_craft/features/request/widgets/tabs/script_tab.dart';
import 'package:api_craft/features/request/widgets/tabs/tab_titles.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';
import 'package:flutter_popup/flutter_popup.dart';

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
    BodyTab(id: widget.node.id),
    QueryParamsTab(id: widget.node.id),
    HeadersTab(id: widget.node.id),
    AuthTab(id: widget.node.id),
    ScriptTab(id: widget.node.id),
  ];

  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );

  late final _provider = reqComposeProvider(widget.node.id);
  late final _repo = ref.read(repositoryProvider);
  final debouncer = DebouncerFlush(Duration(milliseconds: 800));
  int _index = 0;
  final GlobalKey<CustomPopupState> _menuKey = GlobalKey();

  @override
  void dispose() {
    debouncer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing Request Tab for ${widget.node.name}");
    ref.listenManual(_provider.select((d) => d.node), (_, v) {
      debouncer.run(() {
        if (!mounted) return;
        debugPrint("req-tab:: debounce ${v.name} ");
        _repo.updateNode(v);
      });
    }, fireImmediately: false);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("building::: Request Tab");

    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        children: [
          RequestUrl(id: widget.node.id),
          SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: TabBar(
              dividerColor: Colors.transparent,
              onTap: (index) {
                if (_index == 0 && index == 0) {
                  _menuKey.currentState?.show();
                }
                setState(() {
                  _index = index;
                });
              },
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,

              indicatorWeight: 1,
              indicator: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              labelPadding: .symmetric(horizontal: 10),
              // indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: [
                if (widget.node.requestType == RequestType.ws)
                  WsBodyHeader(id: widget.node.id, popupKey: _menuKey)
                else
                  BodyHeader(id: widget.node.id, popupKey: _menuKey),
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
                            (value.inheritedHeaders.length),
                      ),
                    );
                    return Tab(
                      text:
                          "Headers${headersCount > 0 ? ' ($headersCount)' : ''}",
                    );
                  },
                ),
                AuthTabHeader(widget.node.id, controller: _tabController),
                const Tab(text: "Scripts"),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LazyLoadIndexedStack(index: _index, children: children),
          ),
        ],
      ),
    );
  }
}

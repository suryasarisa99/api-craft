import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/features/response/response_headers.dart';
import 'package:api_craft/features/response/widgets/response_body_tab.dart';
import 'package:api_craft/features/response/widgets/response_info_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

enum BodyViewMode { pretty, raw }

class ResponseTAb extends ConsumerStatefulWidget {
  const ResponseTAb({super.key});

  @override
  ConsumerState<ResponseTAb> createState() => _ResponseTAbState();
}

class _ResponseTAbState extends ConsumerState<ResponseTAb>
    with SingleTickerProviderStateMixin {
  BodyViewMode _bodyViewMode = BodyViewMode.pretty;
  final GlobalKey<CustomPopupState> _menuKey = GlobalKey();
  late TabController _tabController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(activeReqIdProvider);
    if (id == null) {
      return const Center(child: Text("No Active Request"));
    }
    final node = ref.watch(activeReqProvider);
    if (node == null) {
      return const Center(child: Text("No Active Request"));
    }
    final response = ref.watch(
      reqComposeProvider(id).select((d) => d.history?.firstOrNull),
    );
    if (response == null) {
      return const Center(child: Text("No Response Available"));
    }

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            onTap: (index) {
              if (index == 0 && _index == 0) {
                _menuKey.currentState?.show();
              }
              setState(() {
                _index = index;
              });
            },
            tabs: [
              IgnorePointer(
                child: MyCustomMenu.contentColumn(
                  popupKey: _menuKey,
                  items: [
                    CustomMenuIconItem.tick(
                      title: const Text("Pretty"),
                      value: "pretty",
                      checked: _bodyViewMode == BodyViewMode.pretty,
                      onTap: (_) =>
                          setState(() => _bodyViewMode = BodyViewMode.pretty),
                    ),
                    CustomMenuIconItem.tick(
                      title: const Text("Raw"),
                      value: "raw",
                      checked: _bodyViewMode == BodyViewMode.raw,
                      onTap: (_) =>
                          setState(() => _bodyViewMode = BodyViewMode.raw),
                    ),
                  ],
                  child: Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _bodyViewMode == BodyViewMode.pretty
                              ? "Pretty"
                              : "Raw",
                        ),
                        const Icon(Icons.arrow_right, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const Tab(text: "Headers"),
              const Tab(text: "Info"),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LazyLoadIndexedStack(
            index: _index,
            children: [
              ResponseBodyTab(response: response, mode: _bodyViewMode),
              ResponseHeaders(id: id),
              ResponseInfoTab(response: response),
            ],
          ),
        ),
      ],
    );
  }
}

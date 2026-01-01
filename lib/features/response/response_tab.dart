import 'package:api_craft/core/providers/providers.dart';

import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/response/response_headers.dart';
import 'package:api_craft/features/response/response_provider.dart';
import 'package:api_craft/features/response/widgets/response_body_tab.dart';
import 'package:api_craft/features/response/widgets/response_info_tab.dart';
import 'package:api_craft/features/response/widgets/response_status_bar.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/request/providers/ws_provider.dart';
import 'package:api_craft/features/response/widgets/ws_response_tab.dart';
import 'package:suryaicons/bulk_rounded.dart';

enum BodyViewMode { pretty, raw, hex, json }

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
    final isSending = ref.watch(
      reqComposeProvider(id).select((d) => d.isSending),
    );
    final sendError = ref.watch(
      reqComposeProvider(id).select((d) => d.sendError),
    );
    // final sendStartTime = ref.watch(
    //   reqComposeProvider(id).select((d) => d.sendStartTime),
    // );

    final response = ref.watch(responseProvider(id));

    if (node.requestType == RequestType.ws) {
      final wsState = ref.watch(wsRequestProvider(id));

      Color statusColor = Colors.transparent;
      String statusText = "No Response";

      if (wsState.isConnected) {
        statusColor = Colors.green;
        statusText = "Connected";
      } else if (wsState.isConnecting) {
        statusColor = Colors.orange;
        statusText = "Connecting...";
      } else if (wsState.messages.isNotEmpty) {
        statusColor = Colors.red;
        statusText = "Disconnected";
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (statusColor != Colors.transparent)
                  Icon(Icons.circle, color: statusColor, size: 10),
                if (statusColor != Colors.transparent) const SizedBox(width: 8),
                Text(
                  statusText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text("${wsState.messages.length} Messages"),
                const SizedBox(width: 8),
                MyCustomMenu.contentColumn(
                  popupKey: GlobalKey<CustomPopupState>(),
                  items: [
                    CustomMenuIconItem(
                      icon: const SuryaThemeIcon(BulkRounded.delete01),
                      title: const Text("Clear History"),
                      value: "clear_history",
                      onTap: (_) {
                        ref
                            .read(wsRequestProvider(id).notifier)
                            .clearHistoryRequest();
                      },
                    ),
                    const LabeledDivider(text: "Sessions"),
                    ...wsState.history.mapIndexed((i, session) {
                      final isSelected =
                          wsState.selectedSessionId == session.id;
                      return CustomMenuIconItem.tick(
                        checked: isSelected,
                        title: Text(
                          "${session.startTime.toString().split('.')[0]}",
                        ),
                        value: session.id,
                        onTap: (_) {
                          ref
                              .read(wsRequestProvider(id).notifier)
                              .selectSession(session.id);
                        },
                      );
                    }),
                  ],
                  child: Icon(Icons.more_vert, size: 16),
                ),
              ],
            ),
          ),
          Expanded(child: WsResponseTab(requestId: id)),
        ],
      );
    }

    // HTTP VIEW

    // Always show status bar if we have ANY meaningful state (sending, error, or response)
    // If absolutely nothing (fresh start), maybe show persistent empty bar or "No Response" text?
    // User asked "info bar shows always for all http requests even if it get error sending request."

    return Column(
      children: [
        // 1. Status Bar
        ResponseStatusBar(
          requestId: id,
          response: response,
          isSending: isSending,
          error: sendError ?? response?.errorMessage,
        ),

        // 2. Content Area
        if (isSending)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (sendError != null)
          Expanded(child: _ErrorSearch(error: sendError))
        else if (response?.errorMessage != null)
          Expanded(child: _ErrorSearch(error: response!.errorMessage!))
        else if (response == null)
          const Expanded(child: Center(child: Text("No Response Available")))
        else
          Expanded(
            child: Column(
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
                          useBtn: false,
                          items: [
                            CustomMenuIconItem.tick(
                              title: const Text("Pretty"),
                              value: "pretty",
                              checked: _bodyViewMode == BodyViewMode.pretty,
                              onTap: (_) => setState(
                                () => _bodyViewMode = BodyViewMode.pretty,
                              ),
                            ),
                            CustomMenuIconItem.tick(
                              title: const Text("Raw"),
                              value: "raw",
                              checked: _bodyViewMode == BodyViewMode.raw,
                              onTap: (_) => setState(
                                () => _bodyViewMode = BodyViewMode.raw,
                              ),
                            ),
                            CustomMenuIconItem.tick(
                              title: const Text("Hex"),
                              value: "hex",
                              checked: _bodyViewMode == BodyViewMode.hex,
                              onTap: (_) => setState(
                                () => _bodyViewMode = BodyViewMode.hex,
                              ),
                            ),
                            CustomMenuIconItem.tick(
                              title: const Text("Json"),
                              value: "json",
                              checked: _bodyViewMode == BodyViewMode.json,
                              onTap: (_) => setState(
                                () => _bodyViewMode = BodyViewMode.json,
                              ),
                            ),
                          ],
                          child: Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _bodyViewMode == BodyViewMode.pretty
                                      ? "Pretty"
                                      : _bodyViewMode == BodyViewMode.raw
                                      ? "Raw"
                                      : _bodyViewMode == BodyViewMode.hex
                                      ? "Hex"
                                      : "Json",
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16),
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
            ),
          ),
      ],
    );
  }

  // _getHistoryList moved to ResponseStatusBar
}

class _ErrorSearch extends StatelessWidget {
  final String error;
  const _ErrorSearch({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            SelectableText(
              "Error: $error",
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

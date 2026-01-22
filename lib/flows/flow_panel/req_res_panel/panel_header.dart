import 'package:api_craft/flows/flow_panel/flow_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

class ResizeService {
  final MultiSplitViewController controller;
  ResizeService(this.controller);

  bool get isSinglePanel => controller.areasCount == 1;
  bool get firstPanelHidden => controller.areas.first.data != 'req-panel';
  bool get secondPanelHidden => isSinglePanel && !firstPanelHidden;

  void showBoth() {
    controller.areas = kReqResAreas;
  }

  void showFirstChild() => showBoth();
  void showSecondChild() => showBoth();
  void hideReqPanel() {
    controller.areas = [controller.areas.last];
  }

  void hideResPanel() {
    controller.areas = [controller.areas.first];
  }
}

class PanelHeader extends ConsumerWidget {
  PanelHeader({
    // required this.codeControllerService,
    required this.resizeController,
    required this.tabController,
    required this.title,
    required this.panelTabs,
    required this.tabIndex,
    super.key,
  });

  final MultiSplitViewController resizeController;
  final TabController tabController;
  final String title;
  final Widget panelTabs;
  final ValueNotifier<int> tabIndex;
  late final resizeService = ResizeService(resizeController);

  bool get isRequest => title == "request";

  static const reqTitles = [
    "Headers",
    "Query Params",
    "Cookies",
    "Body",
    "Raw",
  ];
  static const resTitles = ["Headers", "Body", "Raw"];

  void showBoth() {
    resizeController.areas = kReqResAreas;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: .new(0xff161819),
        border: Border(bottom: .new(color: Colors.grey.shade800, width: 0.5)),
      ),
      child: Row(
        children: [
          // SizedBox(width: 10),

          // Panel title or toggle buttons
          PanelHeaderBtns(resizeController: resizeController, isReq: isRequest),
          const SizedBox(width: 12),

          // Tab bar for different views
          Expanded(child: SizedBox(height: 28, child: panelTabs)),

          // save/cancel buttons
          // ValueListenableBuilder<bool>(
          //   valueListenable: codeControllerService.isModified,
          //   builder: (context, value, _) {
          //     return value
          //         ? Row(
          //             mainAxisSize: .min,
          //             children: [
          //               TextButton(
          //                 onPressed: () {
          //                   codeControllerService.handleSave();
          //                 },
          //                 child: const Text('Save'),
          //               ),
          //               const SizedBox(width: 8),
          //               TextButton(
          //                 onPressed: () {
          //                   codeControllerService.handleCancel();
          //                 },
          //                 child: const Text('Cancel'),
          //               ),
          //             ],
          //           )
          //         : const SizedBox.shrink();
          //   },
          // ),
          const SizedBox(width: 8),
          Tooltip(
            richMessage: WidgetSpan(
              child: ValueListenableBuilder<int>(
                valueListenable: tabIndex,
                builder: (context, value, child) {
                  return Text(
                    'Copy ${isRequest ? reqTitles[value] : resTitles[value]}',
                  );
                },
              ),
            ),
            child: IconButton(
              onPressed: () {
                final index = tabController.index;
                debugPrint('Copy button pressed on tab index: $index');
                String? str;
                switch (index) {
                  case 0:
                    {
                      debugPrint('Copying headers');
                      // str = listToString(
                      //   ref.flows[id]!.request!.getEnabledHeadersOnly(),
                      //   keyValueSeparator: ': ',
                      //   itemSeparator: '\n',
                      // );
                    }
                  case 1:
                    {
                      debugPrint('Copying query params');
                      // str = listToString(
                      //   ref.flows[id]!.request!.getEnabledQueryParamsOnly(),
                      //   keyValueSeparator: '=',
                      //   itemSeparator: '&',
                      // );
                    }
                  case 2:
                    {
                      // debugPrint('Copying cookies');
                      // str = ref.mitmBodyService.getBodyString(id);
                    }
                }
                // if (str != null) {
                //   Clipboard.setData(ClipboardData(text: str));
                // }
              },
              icon: Icon(Icons.copy, size: 16),
            ),
          ),
          IconButton(
            iconSize: 22,
            splashRadius: 16,
            padding: const .all(0.0),
            onPressed: () {
              debugPrint(
                'isReq: $isRequest, single: ${resizeService.isSinglePanel}, firstHidden: ${resizeService.firstPanelHidden} , secondHidden: ${resizeService.secondPanelHidden}',
              );
              if (isRequest) {
                if (resizeService.secondPanelHidden) {
                  resizeService.showSecondChild();
                } else {
                  resizeService.hideResPanel();
                }
              } else {
                if (resizeService.firstPanelHidden) {
                  resizeService.showFirstChild();
                } else {
                  resizeService.hideReqPanel();
                }
              }
            },
            icon: Icon(
              isRequest
                  ? (resizeService.firstPanelHidden
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen)
                  : (resizeService.secondPanelHidden
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
    );
  }

  String listToString(
    List<List<String>> list, {
    String keyValueSeparator = ': ',
    String itemSeparator = '\n',
  }) {
    return list.map((item) => item.join(keyValueSeparator)).join(itemSeparator);
  }
}

class PanelHeaderBtns extends StatefulWidget {
  const PanelHeaderBtns({
    super.key,
    required this.resizeController,
    required this.isReq,
  });
  final MultiSplitViewController resizeController;
  final bool isReq;

  @override
  State<PanelHeaderBtns> createState() => _PanelHeaderBtnsState();
}

class _PanelHeaderBtnsState extends State<PanelHeaderBtns> {
  late final resizeService = ResizeService(widget.resizeController);

  @override
  void initState() {
    super.initState();
    widget.resizeController.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.resizeController.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (resizeService.isSinglePanel) {
      return Padding(
        padding: const .only(left: 10),
        child: _buildToggleButtons(),
      );
    } else {
      // return Text(
      //   widget.isReq ? "Req" : "Res",
      //   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      // );
      return const SizedBox.shrink();
    }
  }

  Widget _buildToggleButtons() {
    return Padding(
      padding: const .symmetric(vertical: 2.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: .min, // Make the row wrap its content
          children: <Widget>[
            _buildToggleButton(
              context,
              text: 'Req',
              isSelected: !resizeService.firstPanelHidden,
              onPressed: () {
                resizeService.showFirstChild();
                resizeService.hideResPanel();
              },
            ),
            _buildToggleButton(
              context,
              text: 'Res',
              isSelected: !resizeService.secondPanelHidden,
              onPressed: () {
                resizeService.showSecondChild();
                resizeService.hideReqPanel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(0),
      child: Container(
        color: isSelected ? cs.primary : const .fromARGB(197, 66, 66, 66),
        padding: const .symmetric(horizontal: 14.0, vertical: 0.5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? cs.onPrimary : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

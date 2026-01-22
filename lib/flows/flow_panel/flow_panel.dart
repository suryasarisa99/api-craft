import 'package:api_craft/flows/flow_panel/flow_panel_url.dart';
import 'package:api_craft/flows/flow_panel/req_res_panel/req_panel.dart';
import 'package:api_craft/flows/flow_panel/req_res_panel/res_panel.dart';
import 'package:api_craft/flows/flow_panel/selected_flow_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

class FlowPanel extends ConsumerStatefulWidget {
  const FlowPanel({super.key});

  @override
  ConsumerState<FlowPanel> createState() => _FlowPanelState();
}

final kReqResAreas = [
  Area(data: 'req-panel', flex: 1),
  Area(data: 'res-panel', flex: 1),
];

class _FlowPanelState extends ConsumerState<FlowPanel> {
  final controller = MultiSplitViewController(areas: kReqResAreas);

  @override
  Widget build(BuildContext context) {
    final flowId = ref.watch(selectedFlowIdProvider);
    return Container(
      child: Column(
        children: [
          FlowDetailURL(),
          Expanded(
            child: MultiSplitView(
              antiAliasingWorkaround: true,
              controller: controller,
              builder: (context, vArea) {
                if (vArea.data == 'req-panel') {
                  return RequestPanel(resizeController: controller);
                }
                if (vArea.data == 'res-panel') {
                  return ResponsePanel(resizeController: controller);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

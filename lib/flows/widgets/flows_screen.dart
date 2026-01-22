import 'package:api_craft/core/widgets/ui/top_bar.dart';
import 'package:api_craft/features/panel/status_bar.dart';
import 'package:api_craft/features/themes/theme.dart';
import 'package:api_craft/flows/flow_panel/flow_panel.dart';
import 'package:api_craft/flows/flow_panel/selected_flow_provider.dart';
import 'package:api_craft/flows/providers/flows_provider.dart';
import 'package:api_craft/flows/widgets/flows_list.dart';
import 'package:api_craft/flows/providers/server_provider.dart';
import 'package:api_craft/packages/dt_table/dt_models.dart';
import 'package:api_craft/packages/dt_table/dt_table.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

class FlowsScreen extends ConsumerStatefulWidget {
  const FlowsScreen({super.key});

  @override
  ConsumerState<FlowsScreen> createState() => _FlowListScreenState();
}

class _FlowListScreenState extends ConsumerState<FlowsScreen> {
  // Single data source for all flows

  // Controller for the data grid to track selection and highlighting
  final _dtController = DtController();

  final _multiSplitController = MultiSplitViewController(
    areas: [Area(data: 'flow-list', flex: 1)],
  );

  late final flowsListWidget = FlowList(controller: _dtController);
  late final flowPanelWidget = FlowPanel();

  @override
  void initState() {
    super.initState();
    ref.read(serverProvider);
    _dtController.addSpecificListener(_flowIdListener);
  }

  @override
  void dispose() {
    _dtController.removeSpecificListener();
    super.dispose();
  }

  void _flowIdListener(DtControllerChange change) {
    if (change.type == ChangeType.focusedRow) {
      String? rowId = _dtController.focusedRowId;
      debugPrint('rowId: $rowId');
      if (rowId == null) {
        _multiSplitController.areas = [Area(data: 'flow-list', flex: 1)];
        ref.read(selectedFlowIdProvider.notifier).reset();
        return;
      }
      final flowId = ref.read(selectedFlowIdProvider);
      if (rowId != flowId) {
        debugPrint('rowId != flowId');
        _multiSplitController.areas = [
          Area(data: 'flow-list', flex: 1),
          Area(data: 'flow-panel', size: 300),
        ];
        ref.read(selectedFlowIdProvider.notifier).set(rowId);
      }
    }
  }

  void launchInterceptorDialog() {}

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(body: _buildBody()),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final appTheme = theme.extension<AppTheme>()!;
    return Column(
      crossAxisAlignment: .start,
      children: [
        TopBar(left: [], right: []),
        // Expanded(child: FlowList(controller: _dtController)),
        Expanded(
          child: MultiSplitViewTheme(
            data: MultiSplitViewThemeData(
              dividerThickness: 0.8,
              dividerHandleBuffer:
                  MultiSplitViewThemeData.defaultDividerHandleBuffer + 4,
              dividerPainter: DividerPainters.background(
                color: appTheme.divider ?? theme.dividerColor,
                highlightedColor: appTheme.hoverDivider ?? Colors.grey,
                // highlightedColor: const Color.fromARGB(255, 92, 92, 92),
              ),
            ),
            child: MultiSplitView(
              axis: Axis.vertical,
              antiAliasingWorkaround: true,
              controller: _multiSplitController,
              builder: (context, vArea) {
                if (vArea.data == 'flow-list') {
                  return flowsListWidget;
                }
                if (vArea.data == 'flow-panel') {
                  return flowPanelWidget;
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        StatusBar(),
      ],
    );
  }
}

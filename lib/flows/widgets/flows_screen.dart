import 'package:api_craft/core/widgets/ui/top_bar.dart';
import 'package:api_craft/features/interception/providers/interception_provider.dart';
import 'package:api_craft/features/interception/widgets/interception_dialog.dart';
import 'package:api_craft/features/panel/bottom_panel.dart';
import 'package:api_craft/features/panel/status_bar.dart';
import 'package:api_craft/features/themes/models/theme_model.dart';
import 'package:api_craft/flows/filter/condition_provider.dart';
import 'package:api_craft/flows/filter/filter_popup.dart';
import 'package:api_craft/flows/flow_panel/flow_panel.dart';
import 'package:api_craft/flows/flow_panel/selected_flow_provider.dart';
import 'package:api_craft/flows/widgets/flows_list.dart';
import 'package:api_craft/flows/providers/server_provider.dart';
import 'package:api_craft/packages/dt_table/dt_models.dart';
import 'package:api_craft/packages/dt_table/dt_table.dart';
import 'package:api_craft/packages/resize/resize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlowsScreen extends ConsumerStatefulWidget {
  const FlowsScreen({super.key});

  @override
  ConsumerState<FlowsScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends ConsumerState<FlowsScreen> {
  // Single data source for all flows

  // Controller for the data grid to track selection and highlighting
  final _dtController = DtController();

  // final _multiSplitController = MultiSplitViewController(
  //   areas: [Area(data: 'flow-list', flex: 1)],
  // );
  final resizeController = ResizableController();
  late final flowsListWidget = FlowList(controller: _dtController);
  late final flowPanelWidget = FlowPanel();

  @override
  void initState() {
    super.initState();
    ref.read(serverProvider);
    resizeController.hideSecondChild();
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
        resizeController.hideSecondChild();
        ref.read(selectedFlowIdProvider.notifier).reset();
        return;
      }
      final flowId = ref.read(selectedFlowIdProvider);
      if (rowId != flowId) {
        debugPrint('rowId != flowId');
        resizeController.showSecondChild();
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
        TopBar(
          left: [],
          right: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return FilterPopup(
                      filterManager: filterManagerProvider,
                      title: "Filter",
                    );
                  },
                );
              },
              child: Text("filter"),
            ),
            IconButton(
              icon: const Icon(Icons.security, size: 18),
              tooltip: 'Interception Rules',
              onPressed: () {
                final currentRules = ref.read(interceptionProvider);
                showDialog(
                  context: context,
                  builder: (context) => InterceptionDialog(
                    initialRules: currentRules,
                    onSave: (newRules) {
                      ref
                          .read(interceptionProvider.notifier)
                          .setRules(newRules);
                    },
                  ),
                );
              },
            ),
          ],
        ),
        Expanded(
          child: ResizableContainer(
            controller: resizeController,
            axis: Axis.vertical,
            dividerColor: Colors.grey[600]!,
            onDragDividerColor: theme.colorScheme.primary,
            onDragDividerWidth: 3,
            dividerWidth: 1,
            dividerHandleWidth: 18,
            maxRatio: 1,
            child1: flowsListWidget,
            child2: flowPanelWidget,
          ),
        ),
        // Expanded(child: FlowList(controller: _dtController)),
        StatusBar(),
      ],
    );
  }
}

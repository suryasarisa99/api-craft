import 'package:api_craft/shared/ui/surya_theme_icon.dart';
import 'package:api_craft/shared/ui/top_bar.dart';
import 'package:api_craft/traffic/interception_rules/interception_provider.dart';
import 'package:api_craft/traffic/interception_rules/widgets/interception_rules_dialog.dart';
import 'package:api_craft/api_client/panel/status_bar.dart';
import 'package:api_craft/app/themes/models/theme_model.dart';
import 'package:api_craft/traffic/filter/condition_provider.dart';
import 'package:api_craft/shared/filter_conditions/filter_popup.dart';
import 'package:api_craft/traffic/flows/flow_panel/flow_panel.dart';
import 'package:api_craft/traffic/flows/flow_panel/selected_flow_provider.dart';
import 'package:api_craft/traffic/flows/widgets/flows_list.dart';
import 'package:api_craft/traffic/flows/providers/server_provider.dart';
import 'package:api_craft/shared/dt_table/dt_models.dart';
import 'package:api_craft/shared/dt_table/dt_table.dart';
import 'package:api_craft/shared/resize/resize.dart';
import 'package:api_craft/traffic/interceptors/intercept_widgets/interceptor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'package:suryaicons/duotone_rounded.dart';

class FlowsScreen extends ConsumerStatefulWidget {
  const FlowsScreen({super.key});

  @override
  ConsumerState<FlowsScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends ConsumerState<FlowsScreen> {
  final _dtController = DtController();
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
            Consumer(
              builder: (context, ref, child) {
                final serverState = ref.watch(serverProvider);
                return IconButton(
                  icon: SuryaThemeIcon(
                    serverState.value == true
                        ? BulkRounded.pause
                        : DuotoneRounded.play,
                  ),
                  tooltip: serverState.value == true
                      ? 'Stop Server'
                      : 'Start Server',
                  onPressed: () {
                    ref.read(serverProvider.notifier).toggle();
                  },
                );
              },
            ),
            IconButton(
              icon: SuryaThemeIcon(BulkRounded.ThreedScale),
              tooltip: 'Interceptors',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => InterceptorsDialog(),
                );
              },
            ),
            IconButton(
              icon: SuryaThemeIcon(BulkRounded.filterAdd),
              tooltip: 'Filter',
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
            ),
            IconButton(
              icon: SuryaThemeIcon(BulkRounded.edit01),
              tooltip: 'Interception Rules',
              onPressed: () {
                final currentRules = ref.read(interceptionProvider);
                showDialog(
                  context: context,
                  builder: (context) => InterceptionRulesDialog(
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

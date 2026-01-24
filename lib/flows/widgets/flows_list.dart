import 'package:api_craft/features/themes/models/theme_model.dart';
import 'package:api_craft/flows/filter/condition_provider.dart';
import 'package:api_craft/flows/filter/logic/filter_js_service.dart';
import 'package:api_craft/flows/models/flow.dart';
import 'package:api_craft/flows/providers/flows_provider.dart';
import 'package:api_craft/flows/flow_data_source.dart';
import 'package:api_craft/flows/providers/paused_providers.dart';
import 'package:api_craft/packages/dt_table/dt_models.dart';
import 'package:api_craft/packages/dt_table/dt_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

class FlowList extends ConsumerStatefulWidget {
  final DtController controller;
  const FlowList({super.key, required this.controller});

  @override
  ConsumerState<FlowList> createState() => _FlowList();
}

class _FlowList extends ConsumerState<FlowList> {
  final tableFocusNode = FocusNode();

  // We need to keep track of the filtered flows asynchronously
  List<HttpFlow> _currentFilteredFlows = [];
  bool _isFiltering = false;

  late final FlowDataSource _flowDataSource = FlowDataSource(
    initialFlows: _currentFilteredFlows,
    dtController: widget.controller,
    ref: ref,
  );

  @override
  void initState() {
    super.initState();
    // Initial load
    _updateFlows();

    ref.listenManual(flowsProvider, (oldFlows, newFlows) {
      _updateFlows();
    });

    // Listen for filter changes
    ref.listenManual(filterManagerProvider, (previous, next) {
      _updateFlows();
    });

    ref.listenManual(pausedFlowsProvider, (_, paused) {
      _updateFlows();
    });
  }

  Future<void> _updateFlows() async {
    if (!mounted) return;

    final allFlows = ref.read(flowsProvider).values.toList();
    final filter = ref.read(filterManagerProvider).rootFilter;
    final jsService = ref.read(filterJsServiceProvider);

    final List<HttpFlow> filtered = [];

    for (final flow in allFlows) {
      // matches is async now
      if (await filter.matches(flow, jsSession: jsService)) {
        filtered.add(flow);
      }
    }

    if (mounted) {
      _currentFilteredFlows = filtered;
      _flowDataSource.handleFlows(filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerCells = [
      (title: "ID", key: 'id', min: 30, initial: 44),
      (title: "URL", key: 'url', min: 300, initial: 300),
      (title: "Method", key: 'method', min: 40, initial: 80),
      (title: "Status", key: 'status', min: 30, initial: 60),
      (title: "Type", key: 'type', min: 40, initial: 150),
      (title: "Time", key: 'time', min: 40, initial: 100),
      (title: "Duration", key: 'duration', min: 40, initial: 100),
      (title: "Req", key: 'reqLen', min: 40, initial: 100),
      (title: "Res", key: 'resLen', min: 40, initial: 100),
    ];
    final theme = Theme.of(context);
    final flowTableTheme = theme.extension<FlowTableTheme>()!;
    return DtTable(
      focusNode: tableFocusNode,
      source: _flowDataSource,
      controller: widget.controller,
      tableWidth: double.infinity,
      headerHeight: 24,
      headerClr: flowTableTheme.header,
      headerBorderClr: flowTableTheme.headerBorder,
      rowHeight: 32,
      frozenColumnsCount: 1,
      menuProvider: buildContextMenu,
      headerColumns: [
        for (final header in headerCells)
          DtColumn(
            key: header.key,
            title: header.title,
            fontSize: 12,
            initialWidth: header.initial.toDouble(),
            isNumeric: header.key == 'id' || header.key == 'status',
            isExpand: header.key == 'url',
            maxWidth: 1200,
          ),
      ],
    );
  }

  Menu buildContextMenu(MenuRequest e) {
    return Menu(children: []);
  }
}

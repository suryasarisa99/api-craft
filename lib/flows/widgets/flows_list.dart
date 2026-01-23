import 'package:api_craft/features/themes/models/theme_model.dart';
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

  late final FlowDataSource _flowDataSource = FlowDataSource(
    initialFlows: ref.read(flowsProvider).values.toList(),
    dtController: widget.controller,
    ref: ref,
  );

  @override
  void initState() {
    super.initState();
    ref.listenManual(flowsProvider, (oldFlows, newFlows) {
      final flows = newFlows.values.toList();
      debugPrint("@flowsProvider: ${flows.length}");
      _flowDataSource.handleFlows(flows);
    });
    ref.listenManual(pausedFlowsProvider, (_, paused) {
      debugPrint("@pausedFlowsProvider: ${paused.length}");
      _flowDataSource.handleFlows(ref.read(flowsProvider).values.toList());
    });
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
      // tableWidth: MediaQuery.sizeOf(context).width,
      tableWidth: double.infinity,
      headerHeight: 24,
      headerClr: flowTableTheme.header,
      headerBorderClr: flowTableTheme.headerBorder,
      rowHeight: 32,
      frozenColumnsCount: 1,
      menuProvider: buildContextMenu,
      // onKeyEvent: handleKeyEvent,
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

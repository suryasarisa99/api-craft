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

  final Map<String, double> _columnWidths = {
    'id': 44,
    'url': 1180,
    'method': 80,
    'status': 60,
    'type': 150,
    'time': 100,
    'duration': 100,
    'reqLen': 100,
    'resLen': 100,
  };
  @override
  Widget build(BuildContext context) {
    final headerCells = [
      (title: "ID", key: 'id'),
      (title: "URL", key: 'url'),
      (title: "Method", key: 'method'),
      (title: "Status", key: 'status'),
      (title: "Type", key: 'type'),
      (title: "Time", key: 'time'),
      (title: "Duration", key: 'duration'),
      (title: "Req", key: 'reqLen'),
      (title: "Res", key: 'resLen'),
    ];
    return DtTable(
      focusNode: tableFocusNode,
      source: _flowDataSource,
      controller: widget.controller,
      // tableWidth: MediaQuery.sizeOf(context).width,
      tableWidth: double.infinity,
      headerHeight: 24,
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
            initialWidth: _columnWidths[header.key]!,
            isNumeric: header.key == 'id' || header.key == 'status',
            isExpand: header.key == 'url',
            // maxWidth: 1200,
          ),
      ],
    );
  }

  Menu buildContextMenu(MenuRequest e) {
    return Menu(children: []);
  }
}

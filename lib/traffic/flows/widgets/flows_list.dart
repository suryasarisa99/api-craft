import 'dart:io';

import 'package:api_craft/app/themes/models/theme_model.dart';
import 'package:api_craft/shared/resize/resize.dart';
import 'package:api_craft/traffic/filter/condition_provider.dart';
import 'package:api_craft/traffic/filter/logic/filter_js_service.dart';
import 'package:api_craft/traffic/flows/models/flow.dart';
import 'package:api_craft/traffic/flows/providers/flows_provider.dart';
import 'package:api_craft/traffic/flows/flow_data_source.dart';
import 'package:api_craft/traffic/flows/providers/paused_providers.dart';
import 'package:api_craft/shared/dt_table/dt_models.dart';
import 'package:api_craft/shared/dt_table/dt_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

class FlowList extends ConsumerStatefulWidget {
  final DtController dtController;
  final ResizableController resizeController;
  const FlowList({
    super.key,
    required this.dtController,
    required this.resizeController,
  });

  @override
  ConsumerState<FlowList> createState() => _FlowList();
}

class _FlowList extends ConsumerState<FlowList> {
  final tableFocusNode = FocusNode();

  // We need to keep track of the filtered flows asynchronously
  List<HttpFlow> _currentFilteredFlows = [];
  final bool _isFiltering = false;

  late final FlowDataSource _flowDataSource = FlowDataSource(
    initialFlows: _currentFilteredFlows,
    dtController: widget.dtController,
    ref: ref,
  );
  late final FlowsNotifier flowsNotifier = ref.read(flowsProvider.notifier);

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
      (title: "Client", key: 'client', min: 40, initial: 120),
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
      controller: widget.dtController,
      tableWidth: double.infinity,
      headerHeight: 24,
      headerClr: flowTableTheme.header,
      headerBorderClr: flowTableTheme.headerBorder,
      rowHeight: 32,
      frozenColumnsCount: 1,
      menuProvider: buildContextMenu,
      onDoubleClick: (row) => onDoubleClick(row),
      onKeyEvent: onKey,
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

  void onDoubleClick(DtRow row) {
    debugPrint('Double clicked on row ${row.id}');
    widget.resizeController.showSecondChild();
  }

  Iterable<String> get modifiedIds => widget.dtController.selectedRowIds.where(
    (id) =>
        ref.read(flowsProvider)[id]!.reqEdited ||
        ref.read(flowsProvider)[id]!.resEdited,
  );

  bool onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final hk = HardwareKeyboard.instance;
    final isCtrl = Platform.isMacOS ? hk.isMetaPressed : hk.isControlPressed;
    final isAlt = hk.isAltPressed;
    final k = event.logicalKey;
    final flowId = widget.dtController.focusedRowId;
    if (flowId == null) return false;
    final selectedIds = widget.dtController.selectedRowIds;
    if (isCtrl && k == .keyC) {
      copyUrls(selectedIds);
      return true;
    } else if (k == .delete) {
      deleteSelected(selectedIds);
      return true;
    } else if (isCtrl && k == .keyD) {
      duplicateFlows(selectedIds);
      return true;
    }
    return false;
  }

  Menu buildContextMenu(MenuRequest e) {
    final selectedIds = _flowDataSource.dtController.selectedRowIds;
    final modified = modifiedIds;
    final multiple = selectedIds.length > 1;
    return Menu(
      children: [
        MenuAction(
          activator: SingleActivator(LogicalKeyboardKey.keyC, meta: true),
          callback: () => copyUrls(selectedIds),
          title: 'Copy Url${multiple ? 's' : ''}',
        ),
        MenuAction(
          callback: () => duplicateFlows(selectedIds),
          title: "Duplicate",
        ),
        MenuAction(
          attributes: MenuActionAttributes(disabled: modified.isEmpty),
          activator: SingleActivator(LogicalKeyboardKey.backspace, meta: true),
          callback: () => revertChanges(modified),
          title: "Revert Changes",
        ),
        MenuAction(
          title: 'Delete',
          activator: SingleActivator(LogicalKeyboardKey.delete),
          callback: () {
            deleteSelected(selectedIds);
          },
        ),
      ],
    );
  }

  void deleteSelected(Iterable<String> ids) {
    final firstSelectedIndex = _flowDataSource.getIndexByRowId(ids.first);
    flowsNotifier.deleteFlows(ids);

    if (_flowDataSource.effectiveRows.isEmpty) {
      widget.dtController.clearSelection();
      widget.dtController.updateFocusedRow(null);
      return;
    }
    // set selected to same index after deletion, or last if index out of range(if not items after deletion)
    final newFirstFlowId =
        _flowDataSource.effectiveRows.length > firstSelectedIndex
        ? _flowDataSource.effectiveRows[firstSelectedIndex].id
        : _flowDataSource
              .effectiveRows[_flowDataSource.effectiveRows.length - 1]
              .id;
    debugPrint('newFirstFlowId: $newFirstFlowId');
    widget.dtController.updateFocusedRow(newFirstFlowId);
    widget.dtController.setSelectedRows({newFirstFlowId});
  }

  void copyUrls(Set<String> selectedIds) {
    final urls = selectedIds
        .map((id) => ref.read(flowsProvider)[id]?.request?.url)
        .whereType<String>()
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: urls));
  }

  void revertChanges(Iterable<String> modifiedIds) {
    flowsNotifier.revertChanges(modifiedIds);
  }

  void duplicateFlows(Iterable<String> selectedIds) {
    flowsNotifier.duplicateFlows(selectedIds);
  }
}

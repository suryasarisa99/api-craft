import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:api_craft/shared/dt_table/dt_models.dart';
import 'package:api_craft/shared/dt_table/dt_source.dart';
// import 'package:api_craft/widgets/input_blocker.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class DtController extends ChangeNotifier {
  Set<String> _selectedRowIds = {};
  String? _focusedRowId;
  String? _selectionAnchorId;
  int? _sortColumnIndex;
  SortType _sortType = SortType.none;

  void Function(DtControllerChange change)? _onSpecificChange;

  Set<String> get selectedRowIds => Set.from(_selectedRowIds);
  String? get focusedRowId => _focusedRowId;
  String? get selectionAnchorId => _selectionAnchorId;
  int? get sortColumnIndex => _sortColumnIndex;
  SortType get sortType => _sortType;

  void addSpecificListener(void Function(DtControllerChange change) listener) {
    _onSpecificChange = listener;
  }

  void removeSpecificListener() {
    _onSpecificChange = null;
  }

  void _notifySpecificChange(
    ChangeType type,
    dynamic oldValue,
    dynamic newValue,
  ) {
    if (type == ChangeType.selectedRows) {
      if (oldValue.toString() != newValue.toString()) {
        _onSpecificChange?.call(
          DtControllerChange(
            type: type,
            oldValue: oldValue,
            newValue: newValue,
          ),
        );
        notifyListeners();
      }
    } else if (oldValue != newValue) {
      _onSpecificChange?.call(
        DtControllerChange(type: type, oldValue: oldValue, newValue: newValue),
      );
      notifyListeners();
    }
  }

  void setSelectedRows(Set<String> rowIds) {
    final oldValue = Set.from(_selectedRowIds);
    _selectedRowIds = Set.from(rowIds);
    _notifySpecificChange(ChangeType.selectedRows, oldValue, _selectedRowIds);
  }

  void setFocusedRow(String? rowId) {
    final oldValue = _focusedRowId;
    _focusedRowId = rowId;
    _notifySpecificChange(ChangeType.focusedRow, oldValue, _focusedRowId);
  }

  void setSelectionAnchor(String? rowId) {
    final oldValue = _selectionAnchorId;
    _selectionAnchorId = rowId;
    _notifySpecificChange(
      ChangeType.selectionAnchor,
      oldValue,
      _selectionAnchorId,
    );
  }

  void selectAll(List<String> allRowIds) {
    final oldValue = Set.from(_selectedRowIds);
    _selectedRowIds = Set.from(allRowIds);
    _notifySpecificChange(ChangeType.selectedRows, oldValue, _selectedRowIds);
  }

  void clearSelection() {
    final oldSelectedRows = Set.from(_selectedRowIds);
    final oldFocusedRow = _focusedRowId;
    final oldSelectionAnchor = _selectionAnchorId;

    _selectedRowIds.clear();
    _focusedRowId = null;
    _selectionAnchorId = null;

    _notifySpecificChange(
      ChangeType.selectedRows,
      oldSelectedRows,
      _selectedRowIds,
    );
    _notifySpecificChange(ChangeType.focusedRow, oldFocusedRow, _focusedRowId);
    _notifySpecificChange(
      ChangeType.selectionAnchor,
      oldSelectionAnchor,
      _selectionAnchorId,
    );
  }

  void updateSelectedRows(Set<String> rowIds) {
    final oldValue = Set.from(_selectedRowIds);
    _selectedRowIds = Set.from(rowIds);
    _notifySpecificChange(ChangeType.selectedRows, oldValue, _selectedRowIds);
  }

  void updateFocusedRow(String? rowId) {
    final oldValue = _focusedRowId;
    _focusedRowId = rowId;
    _notifySpecificChange(ChangeType.focusedRow, oldValue, _focusedRowId);
  }

  void updateSelectionAnchor(String? rowId) {
    final oldValue = _selectionAnchorId;
    _selectionAnchorId = rowId;
    _notifySpecificChange(
      ChangeType.selectionAnchor,
      oldValue,
      _selectionAnchorId,
    );
  }

  void updateSort(int? columnIndex, SortType sortType) {
    final oldColumnIndex = _sortColumnIndex;
    final oldSortType = _sortType;

    _sortColumnIndex = columnIndex;
    _sortType = sortType;

    _notifySpecificChange(
      ChangeType.sortColumn,
      oldColumnIndex,
      _sortColumnIndex,
    );
    _notifySpecificChange(ChangeType.sortType, oldSortType, _sortType);
  }
}

class DtTable extends StatefulWidget {
  const DtTable({
    required this.source,
    required this.headerColumns,
    this.controller,
    this.rowHeight = 48.0,
    this.headerHeight = 56.0,
    this.frozenColumnsCount = 0,
    this.resizeIndicatorColor = Colors.blueAccent,
    super.key,
    this.tableWidth,
    this.onKeyEvent,
    this.focusNode,
    this.headerClr = Colors.grey,
    this.headerBorderClr = Colors.grey,
    required this.menuProvider,
    this.allowTableWidthShrinking = false,
  });

  final bool allowTableWidthShrinking;

  final DtSource source;
  final DtController? controller;
  final double rowHeight;
  final List<DtColumn> headerColumns;
  final double headerHeight;
  final Color headerClr;
  final Color headerBorderClr;
  final Color resizeIndicatorColor;
  final int frozenColumnsCount;
  final double? tableWidth;
  final bool Function(KeyEvent event)? onKeyEvent;
  final FutureOr<Menu?> Function(MenuRequest) menuProvider;
  final FocusNode? focusNode;

  @override
  State<DtTable> createState() => _DtTableState();
}

class _DtTableState extends State<DtTable> {
  late List<double>
  _manualColumnWidths; // Stores the user-set or initial "manual" widths
  late List<double> _columnWidths; // Stores the effective display widths
  late DtController _controller;
  double _actualTableWidth = 0;

  late final ScrollController _verticalController = ScrollController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  String? _lastFocusedRowId;

  bool _isResizing = false;
  int _resizingColumnIndex = -1;
  double _resizeStartWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? DtController();
    _lastFocusedRowId = _controller.focusedRowId;
    widget.source.addListener(_onDataSourceChanged);
    _controller.addListener(_onControllerChanged);
    _manualColumnWidths = widget.headerColumns
        .map((c) => c.initialWidth)
        .toList();
    _columnWidths = List.from(_manualColumnWidths);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.focusedRowId != null) {
        final index = widget.source.effectiveRows.indexWhere(
          (r) => r.id == _controller.focusedRowId,
        );
        if (index != -1) {
          _scrollToRow(index);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // LayoutBuilder will handle width updates, so we don't need logic here for width.
  }

  @override
  void didUpdateWidget(DtTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) {
      oldWidget.source.removeListener(_onDataSourceChanged);
      widget.source.addListener(_onDataSourceChanged);
    }
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _controller.removeListener(_onControllerChanged);
      }
      _controller = widget.controller ?? DtController();
      _controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.source.removeListener(_onDataSourceChanged);
    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _verticalController.dispose();
    super.dispose();
  }

  void _updateTableWidth(double parentWidth) {
    double newTableWidth = widget.tableWidth ?? 0;
    if (widget.tableWidth == double.infinity || widget.tableWidth == null) {
      newTableWidth = parentWidth;
    }

    if (_actualTableWidth != newTableWidth) {
      _actualTableWidth = newTableWidth;
      _redistributeWidth();
    }
  }

  void _redistributeWidth() {
    // 1. Calculate total manual width
    final totalManualWidth = _manualColumnWidths.reduce((a, b) => a + b);

    // 2. Identify Fill Target
    // If allowShrinking is TRUE: Target is Last Column (Floor Filler).
    // If allowShrinking is FALSE: Target is Expand Column (Standard Filler).
    int fillTargetIndex = -1;

    if (widget.allowTableWidthShrinking) {
      fillTargetIndex = widget.headerColumns.length - 1;
    } else {
      fillTargetIndex = widget.headerColumns.indexWhere((c) => c.isExpand);
      // Fallback if no expand column
      if (fillTargetIndex == -1) {
        fillTargetIndex = widget.headerColumns.length - 1;
      }
    }

    // 3. Calculate Gap
    final gap = _actualTableWidth - totalManualWidth;

    // 4. Distribute Gap
    // We only create effective `_columnWidths` here.
    _columnWidths = List.from(_manualColumnWidths);

    if (gap > 0 && fillTargetIndex != -1) {
      _columnWidths[fillTargetIndex] += gap;
    }
  }

  void _onDataSourceChanged() {
    setState(() {
      final allIds = widget.source.effectiveRows.map((e) => e.id).toSet();
      final selectedIds = Set<String>.from(_controller._selectedRowIds);
      selectedIds.removeWhere((id) => !allIds.contains(id));
      _controller.updateSelectedRows(selectedIds);

      if (_controller._focusedRowId != null &&
          !allIds.contains(_controller._focusedRowId)) {
        _controller.updateFocusedRow(null);
      }
      if (_controller._selectionAnchorId != null &&
          !allIds.contains(_controller._selectionAnchorId)) {
        _controller.updateSelectionAnchor(null);
      }
    });
  }

  void _onControllerChanged() {
    if (_controller.focusedRowId != _lastFocusedRowId) {
      _lastFocusedRowId = _controller.focusedRowId;
      if (_lastFocusedRowId != null) {
        final index = widget.source.effectiveRows.indexWhere(
          (r) => r.id == _lastFocusedRowId,
        );
        if (index != -1) {
          _scrollToRow(index);
        }
      }
    }
    setState(() {});
  }

  void _scrollToRow(int dataRowIndex) {
    if (!_verticalController.hasClients) return;

    final double headerHeight = widget.headerHeight;
    final double rowHeight = widget.rowHeight;
    final double viewportHeight =
        _verticalController.position.viewportDimension;
    final double currentOffset = _verticalController.offset;

    // dataRowIndex 0 corresponds to position just after the header.
    // Absolute top of the item in the scrollable content.
    // Note: In TableView, index 0 is header, index 1 is first data row.
    // It seems TableView treats all rows as part of the scrolling extent,
    // but pinned rows stay fixed.
    // So absolute position calculation needs to match TableView's layout.
    // Assuming uniform row height is not guaranteed for header vs rows.
    // Header height: widget.headerHeight. Row height: widget.rowHeight.
    // Top of data row 'i' = headerHeight + i * rowHeight.

    final double itemTopAbsolute = headerHeight + (dataRowIndex * rowHeight);
    final double itemBottomAbsolute = itemTopAbsolute + rowHeight;

    // If itemTop is hidden by the pinned header (which sits at relative 0 to headerHeight)
    // We need itemTopRelative >= headerHeight.
    // itemTopRelative = itemTopAbsolute - currentOffset.
    // So itemTopAbsolute - currentOffset >= headerHeight
    // currentOffset <= itemTopAbsolute - headerHeight
    // If currentOffset > itemTopAbsolute - headerHeight, we are scrolled too far down.
    // Target = itemTopAbsolute - headerHeight = (headerHeight + i*rowHeight) - headerHeight = i*rowHeight.

    final double paddingFromHeader = 0.0; // Optional extra padding

    if (currentOffset > itemTopAbsolute - headerHeight - paddingFromHeader) {
      _verticalController.jumpTo(
        max(0.0, itemTopAbsolute - headerHeight - paddingFromHeader),
      );
    }
    // If itemBottom is below viewport bottom.
    // itemBottomRelative = itemBottomAbsolute - currentOffset.
    // itemBottomRelative <= viewportHeight.
    // itemBottomAbsolute - currentOffset <= viewportHeight.
    // currentOffset >= itemBottomAbsolute - viewportHeight.
    else if (currentOffset < itemBottomAbsolute - viewportHeight) {
      _verticalController.jumpTo(itemBottomAbsolute - viewportHeight);
    }
  }

  void _navigateByOneStep({required bool isDown}) {
    if (widget.source.rowCount == 0) return;

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    int currentIndex = -1;
    if (_controller.focusedRowId != null) {
      currentIndex = widget.source.effectiveRows.indexWhere(
        (r) => r.id == _controller.focusedRowId,
      );
    }

    int nextIndex = currentIndex;
    if (isDown) {
      if (currentIndex < widget.source.rowCount - 1) {
        nextIndex = currentIndex + 1;
      } else if (currentIndex == -1) {
        nextIndex = 0;
      }
    } else {
      if (currentIndex > 0) {
        nextIndex = currentIndex - 1;
      } else if (currentIndex == -1) {
        nextIndex = 0;
      }
    }

    if (nextIndex != currentIndex && nextIndex >= 0) {
      final nextRow = widget.source.effectiveRows[nextIndex];
      _controller.updateFocusedRow(nextRow.id);

      if (isShiftPressed) {
        final anchorIndex = _controller.selectionAnchorId != null
            ? widget.source.effectiveRows.indexWhere(
                (r) => r.id == _controller.selectionAnchorId,
              )
            : -1;
        if (anchorIndex != -1) {
          final start = min(anchorIndex, nextIndex);
          final end = max(anchorIndex, nextIndex);
          final rangeIds = widget.source.effectiveRows
              .sublist(start, end + 1)
              .map((r) => r.id)
              .toSet();
          _controller.updateSelectedRows(rangeIds);
        }
      } else {
        _controller.updateSelectedRows({nextRow.id});
        _controller.updateSelectionAnchor(nextRow.id);
      }
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final isArrowDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isArrowUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isCtrlPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if ((isArrowDown || isArrowUp) && !isCtrlPressed) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _navigateByOneStep(isDown: isArrowDown);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      if ((isArrowDown || isArrowUp) && isCtrlPressed) {
        if (widget.source.rowCount > 0) {
          final targetIndex = isArrowDown ? widget.source.rowCount - 1 : 0;
          final targetRow = widget.source.effectiveRows[targetIndex];

          _controller.updateFocusedRow(targetRow.id);

          if (isShiftPressed) {
            final anchorIndex = _controller.selectionAnchorId != null
                ? widget.source.effectiveRows.indexWhere(
                    (r) => r.id == _controller.selectionAnchorId,
                  )
                : -1;

            if (anchorIndex != -1) {
              final start = min(anchorIndex, targetIndex);
              final end = max(anchorIndex, targetIndex);
              final rangeIds = widget.source.effectiveRows
                  .sublist(start, end + 1)
                  .map((r) => r.id)
                  .toSet();
              _controller.updateSelectedRows(rangeIds);
            }
          } else {
            _controller.updateSelectedRows({targetRow.id});
            _controller.updateSelectionAnchor(targetRow.id);
          }
        }
        return KeyEventResult.handled;
      }

      if (widget.onKeyEvent != null && widget.onKeyEvent!(event)) {
        return KeyEventResult.handled;
      }

      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        final allIds = widget.source.effectiveRows.map((r) => r.id).toList();
        _controller.selectAll(allIds);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _controller.clearSelection();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _handleRowTap(DtRow row) {
    FocusScope.of(context).requestFocus(_focusNode);
    final isCtrlPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    _controller.updateFocusedRow(row.id);

    if (isShiftPressed && _controller._selectionAnchorId != null) {
      final anchorIndex = widget.source.effectiveRows.indexWhere(
        (r) => r.id == _controller._selectionAnchorId,
      );
      final currentIndex = widget.source.effectiveRows.indexWhere(
        (r) => r.id == row.id,
      );
      if (anchorIndex != -1 && currentIndex != -1) {
        final start = min(anchorIndex, currentIndex);
        final end = max(anchorIndex, currentIndex);
        final rangeIds = widget.source.effectiveRows
            .sublist(start, end + 1)
            .map((r) => r.id)
            .toSet();
        if (isCtrlPressed) {
          final selectedIds = Set<String>.from(_controller._selectedRowIds);
          selectedIds.addAll(rangeIds);
          _controller.updateSelectedRows(selectedIds);
        } else {
          _controller.updateSelectedRows(rangeIds);
        }
      }
    } else if (isCtrlPressed) {
      final selectedIds = Set<String>.from(_controller._selectedRowIds);
      if (selectedIds.contains(row.id)) {
        selectedIds.remove(row.id);
      } else {
        selectedIds.add(row.id);
      }
      _controller.updateSelectedRows(selectedIds);
      _controller.updateSelectionAnchor(row.id);
    } else {
      _controller.updateSelectedRows({row.id});
      _controller.updateSelectionAnchor(row.id);
    }
  }

  void _onColumnResizeStart(int columnIndex) {
    setState(() {
      _isResizing = true;
      _resizingColumnIndex = columnIndex;
      // Sync the manual width to the visual width (especially important for the "fill" column)
      // so that resizing starts from the current visual state.
      _manualColumnWidths[columnIndex] = _columnWidths[columnIndex];
      _resizeStartWidth = _manualColumnWidths[columnIndex];
    });
  }

  void _onColumnResizeUpdate(int columnIndex, double delta) {
    setState(() {
      final column = widget.headerColumns[columnIndex];
      // Apply delta to the MANUAL width
      // Note: _resizeStartWidth was set from _manualColumnWidths,
      // but delta is cumulative from drag start?
      // No, usually delta in GestureDetector is incremental.
      // Wait, onHorizontalDragUpdate delta is incremental.
      // So we should just add delta to current manual width.

      double newManualWidth = _manualColumnWidths[columnIndex] + delta;

      // Constraints
      if (newManualWidth < column.minWidth) {
        newManualWidth = column.minWidth;
      }
      if (column.maxWidth != null && newManualWidth > column.maxWidth!) {
        newManualWidth = column.maxWidth!;
      }

      final double actualDelta =
          newManualWidth - _manualColumnWidths[columnIndex];
      _manualColumnWidths[columnIndex] = newManualWidth;

      // Counter-Balance Logic
      // Function: When resizing 'other', 'expand' column should shrink.
      // Identify Expand Column (The "Flex" column)
      final expandColIndex = widget.headerColumns.indexWhere((c) => c.isExpand);

      if (expandColIndex != -1 && expandColIndex != columnIndex) {
        // We are resizing someone else. Expand column should absorb the change.
        // i.e., shrink by actualDelta.
        double currentFlexWidth = _manualColumnWidths[expandColIndex];
        final flexColumn = widget.headerColumns[expandColIndex];
        double newFlexWidth = currentFlexWidth - actualDelta;

        // Constrain Flex Column
        if (newFlexWidth < flexColumn.minWidth) {
          newFlexWidth = flexColumn.minWidth;
        }
        if (flexColumn.maxWidth != null &&
            newFlexWidth > flexColumn.maxWidth!) {
          newFlexWidth = flexColumn.maxWidth!;
        }

        _manualColumnWidths[expandColIndex] = newFlexWidth;
      }

      // Finally, redistribute the gap (if any)
      _redistributeWidth();
    });
  }

  void _onColumnResizeEnd() {
    setState(() {
      _isResizing = false;
      _resizingColumnIndex = -1;
    });
    _redistributeWidth();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateTableWidth(constraints.maxWidth);

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          canRequestFocus: true,
          onKeyEvent: (node, event) => _handleKeyEvent(event),
          child: TableView.builder(
            pinnedRowCount: 1, // Header row
            pinnedColumnCount: widget.frozenColumnsCount,
            rowCount: widget.source.rowCount + 1, // +1 for header
            columnCount: widget.headerColumns.length,
            rowBuilder: _buildRow,
            columnBuilder: _buildColumn,
            cellBuilder: _buildCell,
            verticalDetails: ScrollableDetails.vertical(
              controller: _verticalController,
            ),
          ),
        );
      },
    );
  }

  TableSpan _buildRow(int index) {
    if (index == 0) {
      // Header row
      return TableSpan(
        extent: FixedTableSpanExtent(widget.headerHeight),
        backgroundDecoration: TableSpanDecoration(color: Colors.grey[850]),
      );
    } else {
      // Data row
      final rowIndex = index - 1;
      final row = widget.source.effectiveRows[rowIndex];
      final isSelected = _controller._selectedRowIds.contains(row.id);

      final dataRowAdapter = widget.source.buildRow(
        context,
        row,
        rowIndex,
        isSelected,
        _controller._focusedRowId == row.id,
      );

      return TableSpan(
        extent: FixedTableSpanExtent(widget.rowHeight),
        backgroundDecoration: TableSpanDecoration(color: dataRowAdapter.color),
      );
    }
  }

  TableSpan _buildColumn(int index) {
    return TableSpan(extent: FixedTableSpanExtent(_columnWidths[index]));
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    final columnIndex = vicinity.column;
    final rowIndex = vicinity.row;

    if (rowIndex == 0) {
      // Header cell
      return TableViewCell(child: _buildHeaderCell(columnIndex));
    } else {
      // Data cell
      return TableViewCell(child: _buildDataCell(columnIndex, rowIndex - 1));
    }
  }

  Widget _buildHeaderCell(int columnIndex) {
    final column = widget.headerColumns[columnIndex];

    return Container(
      decoration: BoxDecoration(
        color: widget.headerClr,
        border: Border(
          bottom: BorderSide(color: widget.headerBorderClr, width: 1),
          right: columnIndex < widget.headerColumns.length - 1
              ? BorderSide(color: widget.headerBorderClr, width: 1)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.source.sort(columnIndex, column.isNumeric),
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        column.title,
                        style: TextStyle(
                          fontSize: column.fontSize,
                          overflow: TextOverflow.ellipsis,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (widget.source.sortColumnIndex == columnIndex)
                      Icon(
                        widget.source.sortType == SortType.ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragStart: (_) => _onColumnResizeStart(columnIndex),
              onHorizontalDragUpdate: (details) =>
                  _onColumnResizeUpdate(columnIndex, details.delta.dx),
              onHorizontalDragEnd: (_) => _onColumnResizeEnd(),
              child: Container(
                width: 8,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(int columnIndex, int rowIndex) {
    final row = widget.source.effectiveRows[rowIndex];
    final isSelected = _controller._selectedRowIds.contains(row.id);
    final hasFocus = _controller._focusedRowId == row.id;

    final dataRowAdapter = widget.source.buildRow(
      context,
      row,
      rowIndex,
      isSelected,
      hasFocus,
    );
    final borderClr = dataRowAdapter.borderColor;
    return ContextMenuWidget(
      menuProvider: (e) {
        if (!(_controller._selectedRowIds.contains(row.id))) {
          _controller.updateSelectedRows({row.id});
          _controller.updateFocusedRow(row.id);
          _controller.updateSelectionAnchor(row.id);
        }
        return widget.menuProvider(e);
      },
      child: InkWell(
        onTap: () => _handleRowTap(row),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          alignment: Alignment.centerLeft,
          decoration: borderClr != null
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderClr)),
                )
              : null,
          child: dataRowAdapter.cells[columnIndex],
        ),
      ),
    );
  }
}

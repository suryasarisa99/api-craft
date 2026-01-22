import 'package:flutter/material.dart';

// enums
enum DtLinesVisibility {
  /// Borders are not drawn.
  none,

  /// Both vertical and horizontal borders are visible.
  both,

  /// Only vertical borders are visible.
  vertical,

  /// Only horizontal borders are visible.
  horizontal,
}

enum SortType { none, ascending, descending }

enum ChangeType {
  focusedRow,
  selectedRows,
  selectionAnchor,
  sortType,
  sortColumn,
}

// --- Data Models ---

class DtColumn {
  final String key;
  final String title;
  final bool isNumeric;
  final double initialWidth;
  final double fontSize;
  final double minWidth;
  final double? maxWidth;
  final bool isExpand;

  const DtColumn({
    required this.key,
    required this.title,
    required this.initialWidth,
    this.fontSize = 14,
    this.minWidth = 40,
    this.maxWidth,
    this.isNumeric = false,
    this.isExpand = false,
  });
}

class DtRow {
  /// Creates [DtRow] for the [DataTable].
  const DtRow({
    required List<DtCell> cells,
    required this.id,
    this.m,
    required this.state,
  }) : _cells = cells;

  /// The data for this row.
  /// There must be exactly as many cells as there are columns in the
  final List<DtCell> _cells;
  final String id;
  final String state;

  /// marker string
  final String? m;

  /// Returns the collection of [DtCell] which is created for
  /// [DtRow].
  List<DtCell> get cells {
    return _cells;
  }
}

class DtCell<T> {
  /// Creates [DtCell] for the [DataTable].
  const DtCell({
    // required this.columnName,
    required this.value,
    this.textAlign = TextAlign.start,
  });

  /// The name of a column, currently removed, based on the order in row it knows it columnName
  // final String columnName;

  /// The value of a cell.
  ///
  /// Provide value of a cell to perform the sorting for whole data available
  /// in datagrid.
  final T? value;

  /// alignment of the cell
  final TextAlign? textAlign;
}

class DtRowAdapter {
  const DtRowAdapter({
    required this.cells,
    this.id,
    this.color,
    this.borderColor,
  });

  /// The key for the row.
  final Key? id;

  /// The color for the row.
  final Color? color;

  /// Bottom border color
  final Color? borderColor;

  /// The widget of each cell for this row.
  ///
  /// There must be exactly as many cells as there are columns in the
  /// [DataTable].
  final List<Widget> cells;
}

class DtControllerChange {
  final ChangeType type;
  final dynamic oldValue;
  final dynamic newValue;

  const DtControllerChange({
    required this.type,
    required this.oldValue,
    required this.newValue,
  });
}

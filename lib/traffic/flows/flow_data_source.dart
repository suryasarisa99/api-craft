import 'dart:typed_data';

import 'package:api_craft/app/themes/models/theme_model.dart';
import 'package:intl/intl.dart';
import 'package:api_craft/traffic/flows/models/flow.dart';
import 'package:api_craft/traffic/flows/providers/paused_providers.dart';
import 'package:api_craft/traffic/flows/providers/server_provider.dart';
import 'package:api_craft/shared/dt_table/dt_models.dart';
import 'package:api_craft/shared/dt_table/dt_source.dart';
import 'package:api_craft/shared/dt_table/dt_table.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/traffic/utils/app_icon_service.dart';
import 'package:mockhttp/types.dart';

class FlowDataSource extends DtSource {
  List<DtRow> _flowRows = [];
  final DtController dtController;
  late final PausedFlowsNotifier pausedFlowsNotifier;
  final WidgetRef ref;
  // void Function(String flowId, String oldState) resumeIntercept;

  FlowDataSource({
    required List<HttpFlow> initialFlows,
    required this.dtController,
    required this.ref,
    // required this.resumeIntercept,
  }) {
    pausedFlowsNotifier = ref.read(pausedFlowsProvider.notifier);
    handleFlows(initialFlows);
  }

  void handleFlows(List<HttpFlow> flows) {
    buildFlowRows(flows);
    updateData();
  }

  void replaceData(List<HttpFlow> flows) {
    handleFlows(flows);
    dtController.clearSelection();
  }

  void buildFlowRows(List<HttpFlow> flows) {
    _flowRows = flows.mapIndexed((i, flow) {
      // final hasResponse = flow.response != null;

      return DtRow(
        id: flow.id,
        m: null,
        state: pausedFlowsNotifier.get(flow.id) ?? "none",
        cells: [
          // 0: ID Cell
          DtCell(value: i, textAlign: TextAlign.right),

          // 1: URL Cell with styled hostname and path
          DtCell(value: flow.request != null ? flow.request!.url : ''),

          // 2: Method Cell
          DtCell(value: flow.request?.method),

          // 3: Client Cell
          DtCell(value: flow.request?.clientInfo),

          // // 4: Status Cell
          DtCell(value: flow.response?.statusCode),

          // // 4: Type Cell
          DtCell(value: flow.response?.contentType?.split(';').first),
          // DtCell(
          //   value: flow.request == null
          //       ? 'TCP'
          //       : flow.isWebSocket
          //       ? 'WebSocket'
          //       : flow.response?.contentType?.split(';').first,
          // ),

          // // 5: Time Cell
          DtCell(value: flow.request?.timingEvents.startTime),
          // DtCell(
          //   value: flow.createdDateTime.toLocal().toString().substring(11, 19),
          // ),

          // // 6: Duration Cell - time between request and response in ms
          DtCell(
            value: flow.response?.timingEvents.responseSentTime != null
                ? (flow.response!.timingEvents.responseSentTime! -
                          flow.request!.timingEvents.startTime)
                      .round()
                : null,
          ),

          // DtCell(
          //   value:
          //       hasResponse &&
          //           flow.response?.timestampEnd != null &&
          //           flow.request?.timestampStart != null
          //       ? ((flow.response!.timestampEnd! -
          //                     flow.request!.timestampStart!) *
          //                 1000)
          //             .round()
          //       : null,
          // ),

          // // 7: Request Length Cell
          DtCell(value: flow.request?.contentLen),

          // // 8: Response Length Cell
          DtCell(value: flow.response?.contentLen),
        ],
      );
    }).toList();
  }

  @override
  List<DtRow> get rows => _flowRows;
  @override
  DtController get controller => dtController;

  @override
  DtRowAdapter buildRow(ctx, row, index, isSelected, hasFocus) {
    final theme = Theme.of(ctx);
    final flowTableTheme = theme.extension<FlowTableTheme>()!;

    // // int? rowId = int.tryParse(row.getCells().first.value);
    late Color rowColor;
    Color cellColor = Colors.white;

    FontWeight? fontWeight;
    if (isSelected) {
      rowColor = flowTableTheme.focusedRow;
      cellColor = theme.colorScheme.onPrimaryContainer;
    } else {
      rowColor = index.isEven ? flowTableTheme.evenRow : flowTableTheme.oddRow;
    }
    final cells = row.cells.mapIndexed((cIndex, cell) {
      late String text;
      if (cell.value == null) {
        text = '-';
      } else {
        text = switch (cIndex) {
          // duration in ms
          6 => duration(cell.value as int),
          // request and response lengths
          7 || 8 => formatBytes(cell.value as int? ?? 0),
          _ => cell.value.toString(),
        };

        if (cIndex == 5 && cell.value != null && cell.value is int) {
          text = DateFormat(
            'HH:mm:ss',
          ).format(DateTime.fromMillisecondsSinceEpoch(cell.value as int));
        }
      }

      if (cIndex == 3) {
        return _buildClientCell(cell.value as ClientInfo?);
      }

      // Color cellColor = switch (cIndex) {
      //   1 =>
      //     row.m != null && row.m!.isNotEmpty
      //         ? MarkCircle.decode(row.m!).getColor(isSelected)
      //         : Colors.white,
      //   2 => getMethodColor(cell.value ?? ''),
      //   3 => getStatusCodeColor(cell.value as int?),
      //   _ => Colors.white,
      // };
      if (cIndex == 1 && row.m != null && row.m!.isNotEmpty) {
        fontWeight = FontWeight.bold;
      }

      if (cIndex == 1 && row.state != 'none') {
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              color: row.state == "req"
                  ? const .new(0xFF9399FF)
                  : const .new(0xFF8BEF8E),
              // onPressed: () => resumeIntercept(row.id, row.state),
              onPressed: () {
                ref.read(serverProvider.notifier).resume(row.id, row.state);
              },
              tooltip: row.state == "req"
                  ? 'Resume to server'
                  : 'Resume to client',
            ),
            SizedBox(width: 4),
            Text(
              text,
              textAlign: cell.textAlign ?? TextAlign.start,
              style: TextStyle(
                color: cellColor,
                fontWeight: fontWeight,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      } else {
        return Text(
          text,
          textAlign: cell.textAlign ?? TextAlign.start,
          style: TextStyle(
            color: cellColor,
            fontWeight: fontWeight,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
    }).toList();
    return DtRowAdapter(
      color: rowColor,
      borderColor: flowTableTheme.rowSeperator,
      cells: cells,
    );
  }

  Widget _buildClientCell(ClientInfo? info) {
    if (info == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final name =
        'p: ${info.processPath?.split('/').last}' ??
        'n: ${info.appName}' ??
        'p: ${info.platform}' ??
        'i: ${info.ipAddress}' ??
        'Unknown';

    final path = info.processPath;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (path != null)
          FutureBuilder<Uint8List?>(
            future: AppIconService.getAppIcon(path),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Image.memory(snapshot.data!, width: 24, height: 24),
                );
              }
              return const SizedBox(width: 22); // spacing placeholder
            },
          ),
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  /// Get the color for a HTTP method (GET, POST, etc.)
  Color getMethodColor(String method) {
    switch (method) {
      case 'GET':
        return const .fromARGB(255, 102, 186, 255);
      case 'POST':
        return const .new(0xFF74E277);
      case 'PUT':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Format bytes into a human-readable string (KB, MB, etc.)
  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String duration(int milli) {
    if (milli <= 1000) {
      return '$milli ms';
    } else {
      return '${milli / 1000} s';
    }
  }
}

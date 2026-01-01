import 'package:api_craft/core/utils/formatters.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/request/providers/request_details_provider.dart';
import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:api_craft/features/response/utils/status_code_clr.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'dart:io';

import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/request/models/node_config_model.dart';

class ResponseStatusBar extends ConsumerWidget {
  final String requestId;
  final RawHttpResponse? response;
  final bool isSending;
  final String? error;

  const ResponseStatusBar({
    super.key,
    required this.requestId,
    this.response,
    this.isSending = false,
    this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSending) {
      return _buildBar(context, ref, [
        const Text("Sending...", style: TextStyle(color: Colors.orange)),
        const Spacer(),
      ]);
    }

    if (error != null) {
      return _buildBar(context, ref, [
        const Text("Error", style: TextStyle(color: Colors.red)),
        const SizedBox(width: 8),
        const Spacer(),
        // Even in error, we might want to delete history etc.
        _buildMenu(context, ref),
      ]);
    }

    if (response == null) {
      // should probably not happen given constraints, or show empty
      return const SizedBox.shrink();
    }

    final sizeInKb = (response!.bodyBytes.length / 1024).toStringAsFixed(2);
    final statusColor = statusCodeColor(response!.statusCode);

    return _buildBar(context, ref, [
      Text(
        "${response!.statusCode} ${response!.statusMessage}",
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
      ),
      const SizedBox(width: 16),
      _buildDetailItem("Time: ", formatDuration(response!.durationMs)),
      const SizedBox(width: 16),
      _buildDetailItem("Size: ", "$sizeInKb KB"),
      const Spacer(),
      _buildMenu(context, ref),
    ]);
  }

  Widget _buildBar(BuildContext context, WidgetRef ref, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: children),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    return MyCustomMenu.contentColumn(
      popupKey: GlobalKey<CustomPopupState>(),
      items: [
        if (response != null) ...[
          CustomMenuIconItem(
            icon: const SuryaThemeIcon(BulkRounded.copy01),
            onTap: (_) async {
              await Clipboard.setData(ClipboardData(text: response!.body));
            },
            title: const Text("Copy Response"),
            value: "copy",
          ),
          CustomMenuIconItem(
            icon: const SuryaThemeIcon(BulkRounded.download01),
            onTap: (_) async {
              String? outputFile = await FilePicker.platform.saveFile(
                dialogTitle: 'Save Response Body',
                fileName: 'response',
              );

              if (outputFile != null) {
                try {
                  final file = File(outputFile);
                  await file.writeAsBytes(response!.bodyBytes);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to save file: $e"),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
            title: const Text("Save Response"),
            value: "save",
          ),
        ],
        CustomMenuIconItem(
          icon: const SuryaThemeIcon(BulkRounded.delete01),
          title: const Text("Delete This Entry"),
          value: "delete",
          disabled: response == null,
          onTap: (value) {
            if (response != null) {
              ref
                  .read(requestDetailsProvider(requestId).notifier)
                  .deleteHistoryEntry(response!.id);
            }
          },
        ),
        LabeledDivider(text: "History"),
        CustomMenuIconItem(
          icon: const SuryaThemeIcon(BulkRounded.delete01),
          title: const Text("Clear History"),
          value: "delete_history",
          onTap: (value) {
            ref
                .read(requestDetailsProvider(requestId).notifier)
                .deleteHistory();
          },
        ),
        ..._getHistoryList(ref),
      ],
      child: const Padding(
        padding: EdgeInsets.all(4.0),
        child: Icon(Icons.more_vert, size: 16),
      ),
    );
  }

  List<Widget> _getHistoryList(WidgetRef ref) {
    final history = ref.watch(
      requestDetailsProvider(requestId).select((s) => s.history),
    );
    final historyId = ref.watch(
      fileTreeProvider.select(
        (s) => (s.nodeMap[requestId]?.config as RequestNodeConfig).historyId,
      ),
    );

    return history?.mapIndexed((i, h) {
          return CustomMenuIconItem.tick(
            checked: historyId != null ? historyId == h.id : i == 0,
            title: Row(
              children: [
                Text(
                  h.statusCode == 0 ? "Err" : h.statusCode.toString(),
                  style: TextStyle(color: statusCodeColor(h.statusCode)),
                ),
                const SizedBox(width: 12),
                Text(formatDuration(h.durationMs)),
              ],
            ),
            value: h.id,
            onTap: (value) {
              ref
                  .read(fileTreeProvider.notifier)
                  .updateRequestHistoryId(requestId, i == 0 ? null : h.id);
            },
          );
        }).toList() ??
        [];
  }
}

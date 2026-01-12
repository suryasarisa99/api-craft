import 'dart:convert';
import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';
import 'package:api_craft/features/console/models/console_log_entry.dart';
import 'package:api_craft/features/console/providers/console_logs_provider.dart';
import 'package:api_craft/features/console/providers/console_filter_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ConsoleTab extends ConsumerStatefulWidget {
  const ConsoleTab({super.key});

  @override
  ConsumerState<ConsoleTab> createState() => _ConsoleTabState();
}

class _ConsoleTabState extends ConsumerState<ConsoleTab> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  Color _getLevelColor(ConsoleLogLevel level, ThemeData theme) {
    switch (level) {
      case ConsoleLogLevel.error:
        return Colors.redAccent;
      case ConsoleLogLevel.warning:
        return Colors.orangeAccent;
      case ConsoleLogLevel.info:
        return Colors.blueAccent;
      case ConsoleLogLevel.debug:
        return const Color.fromARGB(255, 134, 134, 134);
      case ConsoleLogLevel.log:
        return theme.textTheme.bodyMedium?.color ??
            const Color.fromARGB(255, 206, 206, 206);
    }
  }

  IconData? _getLevelIcon(ConsoleLogLevel level) {
    switch (level) {
      case ConsoleLogLevel.error:
        return Icons.error_outline;
      case ConsoleLogLevel.warning:
        return Icons.warning_amber_rounded;
      case ConsoleLogLevel.info:
        return Icons.info_outline;
      case ConsoleLogLevel.debug:
        return Icons.bug_report_outlined;
      case ConsoleLogLevel.log:
        return Icons.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLogs = ref.watch(consoleLogsProvider);
    final filter = ref.watch(consoleFilterProvider);
    final theme = Theme.of(context);

    // Apply Filters
    final logs = allLogs.where((entry) {
      if (!filter.activeLevels.contains(entry.level)) return false;
      if (filter.query.isEmpty) return true;
      // Search in args
      return entry.args.any(
        (arg) =>
            arg.toString().toLowerCase().contains(filter.query.toLowerCase()),
      );
    }).toList();

    // Auto-scroll trigger
    ref.listen(consoleLogsProvider, (previous, next) {
      if (next.length > (previous?.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final entry = logs[index];
          final icon = _getLevelIcon(entry.level);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timestamp & Icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        DateFormat('HH:mm:ss.SSS').format(entry.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      icon,
                      size: 14,
                      color: _getLevelColor(entry.level, theme),
                    ),
                  ],
                ),
                const SizedBox(width: 6),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Render Args
                      ...entry.args.map((arg) => _buildArg(arg, context)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildArg(dynamic arg, BuildContext context) {
    final theme = Theme.of(context);

    if (arg is Map || arg is List) {
      // Code Block
      String content = '';
      try {
        content = const JsonEncoder.withIndent('  ').convert(arg);
      } catch (e) {
        content = arg.toString();
      }
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(4),
        ),
        width: double.infinity,
        child: Text(
          content,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
        // height: 300,
        // child: CFCodeEditor(text: content, language: "json"),
      );
    }

    return Text(
      arg.toString(),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.3,
      ),
    );
  }
}

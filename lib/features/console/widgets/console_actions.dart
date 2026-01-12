import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/console/providers/console_logs_provider.dart';
import 'package:api_craft/features/console/providers/console_filter_provider.dart';
import 'package:api_craft/features/console/widgets/console_filter_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suryaicons/bulk_rounded.dart';

class ConsoleActions extends ConsumerWidget {
  const ConsoleActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // final filter = ref.watch(consoleFilterProvider); // Consumed by child menu

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search
        SizedBox(
          width: 200,
          height: 24,
          child: TextField(
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Filter',
              isDense: true,
              suffixIcon: const Icon(Icons.search, size: 14),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(4),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
            ),
            onChanged: (val) =>
                ref.read(consoleFilterProvider.notifier).setQuery(val),
          ),
        ),
        const SizedBox(width: 8),

        // Filter Menu
        const ConsoleFilterMenu(),

        const SizedBox(width: 8),
        IconButton(
          icon: const SuryaThemeIcon(BulkRounded.delete01),
          tooltip: "Clear Console",
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => ref.read(consoleLogsProvider.notifier).clear(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

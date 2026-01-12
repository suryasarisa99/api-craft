import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/features/console/models/console_log_entry.dart';
import 'package:api_craft/features/console/providers/console_filter_provider.dart';
import 'package:api_craft/features/console/providers/console_logs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsoleFilterMenu extends ConsumerStatefulWidget {
  const ConsoleFilterMenu({super.key});

  @override
  ConsumerState<ConsoleFilterMenu> createState() => _ConsoleFilterMenuState();
}

class _ConsoleFilterMenuState extends ConsumerState<ConsoleFilterMenu> {
  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(consoleFilterProvider);
    final theme = Theme.of(context);

    final activeCount = filter.activeLevels.length;
    final totalLevels = 5; // Error, Warn, Info, Debug, Log

    return MyCustomMenu.contentColumn(
      popupKey: _popupKey,
      width: 200,
      useBtn: true,
      items: [
        // Header
        const _FilterHeader(),
        const Divider(height: 1, color: Colors.grey, thickness: 0.2),
        const SizedBox(height: 4),
        // Items
        // Using distinct class for each to ensure keys/identity if needed? No parameters enough.
        const _FilterItemWrapper(
          level: ConsoleLogLevel.info,
          label: "info",
          icon: Icons.info_outline,
          color: Colors.blueAccent,
        ),
        const _FilterItemWrapper(
          level: ConsoleLogLevel.warning,
          label: "warn",
          icon: Icons.warning_amber_rounded,
          color: Colors.orangeAccent,
        ),
        const _FilterItemWrapper(
          level: ConsoleLogLevel.error,
          label: "error",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        ),
        const _FilterItemWrapper(
          level: ConsoleLogLevel.debug,
          label: "debug",
          icon: Icons.bug_report_outlined,
          color: Color(0xFFC9C9C9),
        ),
        const _FilterItemWrapper(
          level: ConsoleLogLevel.log,
          label: "log",
          icon: Icons.code,
          color: Colors.grey,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              "$activeCount/$totalLevels",
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _FilterHeader extends ConsumerWidget {
  const _FilterHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(consoleFilterProvider);
    final total = 5;
    final allSelected = filter.activeLevels.length == total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Filter by Type",
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          InkWell(
            onTap: () {
              if (allSelected) {
                // Hide All
                ref.read(consoleFilterProvider.notifier).setLevels({});
              } else {
                // Show All
                ref.read(consoleFilterProvider.notifier).setLevels({
                  ConsoleLogLevel.info,
                  ConsoleLogLevel.warning,
                  ConsoleLogLevel.error,
                  ConsoleLogLevel.debug,
                  ConsoleLogLevel.log,
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Text(
                allSelected ? "Hide All" : "Show All",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterItemWrapper extends ConsumerWidget {
  final ConsoleLogLevel level;
  final String label;
  final IconData icon;
  final Color color;

  const _FilterItemWrapper({
    required this.level,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(consoleFilterProvider);
    final logs = ref.watch(consoleLogsProvider);

    // Count locally
    final count = logs.where((l) => l.level == level).length;
    final isChecked = filter.activeLevels.contains(level);

    return InkWell(
      onTap: () => ref.read(consoleFilterProvider.notifier).toggleLevel(level),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isChecked
                    ? const Color(0xFFEAB308)
                    : Colors.transparent, // User image used yellow?
                // Or just system accent. I will use a generic checkbox color.
                // Let's use Theme accent or Orange (from user image).
                // Actually user image uses Orange for checked.
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isChecked ? Colors.transparent : Colors.grey,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isChecked
                  ? const Icon(Icons.check, size: 10, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 8),
            // Icon
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            // Label
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(255, 208, 208, 208),
              ),
            ),
            const Spacer(),
            // Count
            Text(
              "($count)",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

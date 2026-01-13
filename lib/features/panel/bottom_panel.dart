import 'package:api_craft/features/console/widgets/console_actions.dart';
import 'package:api_craft/features/console/widgets/console_tab.dart';
import 'package:api_craft/features/panel/panel_state_provider.dart';
import 'package:api_craft/features/panel/status_bar.dart';
import 'package:api_craft/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

class BottomPanel extends ConsumerWidget {
  const BottomPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panelState = ref.watch(panelStateProvider);
    final theme = Theme.of(context);

    // If implementing maximize logic in HomeScreen, BottomPanel just occupies the space given.
    return Container(
      color: const Color.fromARGB(255, 32, 32, 32),
      child: Column(
        children: [
          // Header
          Container(
            height: 30,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              color: kTopBarClr,
            ),
            child: Row(
              children: [
                // Tabs
                _PanelTab(
                  label: "Console",
                  isActive: panelState.activeIndex == 0,
                  onTap: () =>
                      ref.read(panelStateProvider.notifier).setIndex(0),
                ),

                // Future tabs can be added here
                const Spacer(),

                // Dynamic Actions specific to Tab
                if (panelState.activeIndex == 0) const ConsoleActions(),

                // Fixed Actions (Divider?)
                Container(
                  height: 20,
                  width: 1,
                  color: theme.dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Maximize / Expand
                IconButton(
                  icon: Icon(
                    panelState.isMaximized
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 16,
                  ),
                  tooltip: panelState.isMaximized
                      ? "Restore Panel"
                      : "Maximize Panel",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                  splashRadius: 16,
                  onPressed: () {
                    // Force layout change when button is clicked
                    ref
                        .read(panelStateProvider.notifier)
                        .setMaximized(
                          !panelState.isMaximized,
                          forceLayout: true,
                        );
                  },
                ),
                // Close
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: "Close Panel",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                  splashRadius: 16,
                  onPressed: () {
                    ref.read(isBottomPanelVisibleProvider.notifier).set(false);
                    // Force layout update when closing via button to ensure clean state
                    if (panelState.isMaximized) {
                      ref
                          .read(panelStateProvider.notifier)
                          .setMaximized(false, forceLayout: true);
                    }
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),

          // Body
          Expanded(
            child: LazyLoadIndexedStack(
              index: panelState.activeIndex,
              children: const [
                ConsoleTab(),
                // Future tabs
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PanelTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: isActive
              ? Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : Colors.grey,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

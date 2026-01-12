import 'package:api_craft/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isBottomPanelVisibleProvider =
    NotifierProvider<BottomPanelVisibilityNotifier, bool>(
      BottomPanelVisibilityNotifier.new,
    );

class BottomPanelVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void toggle() {
    state = !state;
  }

  void set(bool value) {
    state = value;
  }
}

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(isBottomPanelVisibleProvider);
    final theme = Theme.of(context);

    return Container(
      height: 22,
      padding: .symmetric(horizontal: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: kTopBarClr,
        // color: theme
        //     .colorScheme
        //     .surfaceContainer, // Similar to VS Code status bar color
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // We can add left aligned items here (git branch, errors, etc)
          const Spacer(),
          // Right aligned items
          InkWell(
            onTap: () {
              ref.read(isBottomPanelVisibleProvider.notifier).toggle();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              height: 24,
              // color: isVisible
              //     ? theme.colorScheme.primary.withValues(alpha: 0.2)
              //     : Colors.transparent,
              child: Row(
                children: [
                  Icon(
                    Icons.terminal,
                    size: 14,
                    color: isVisible ? theme.colorScheme.primary : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Console",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isVisible
                          ? theme.colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

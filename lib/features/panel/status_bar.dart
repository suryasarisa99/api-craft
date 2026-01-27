import 'package:api_craft/core/screens/home_screen.dart';
import 'package:api_craft/features/themes/models/theme_model.dart';
import 'package:api_craft/features/settings/settings_dialog.dart';
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
    final appTheme = theme.extension<AppTheme>()!;

    return Container(
      height: 22,
      padding: .symmetric(horizontal: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: appTheme.statusBarBackground,
        border: Border(
          top: BorderSide(
            color: appTheme.statusBarBorder ?? theme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left aligned items
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const SettingsDialog(),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Icon(
                Icons.settings,
                size: 14,
                color: appTheme.statusBarText,
              ),
            ),
          ),
          SizedBox(width: 8),
          InkWell(
            onTap: () {
              ref.read(screenProvider.notifier).toggle();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Icon(Icons.api, size: 14, color: appTheme.statusBarText),
            ),
          ),

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

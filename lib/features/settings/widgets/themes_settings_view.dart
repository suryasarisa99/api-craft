import 'package:api_craft/core/services/theme_service.dart';
import 'package:api_craft/features/themes/app_themes.dart';
import 'package:api_craft/features/themes/models/theme_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemesSettingsView extends ConsumerStatefulWidget {
  const ThemesSettingsView({super.key});

  @override
  ConsumerState<ThemesSettingsView> createState() => _ThemesSettingsViewState();
}

class _ThemesSettingsViewState extends ConsumerState<ThemesSettingsView> {
  // We can filter by "All", "Dark", "Light" if strictly needed,
  // but User asked: "provide option to display light/dark themes (use menu btn for it). so we only display light or dark themes"
  bool _showDark = true;

  @override
  Widget build(BuildContext context) {
    // 1. Filter themes based on _showDark
    final allThemes = AppThemes.themes;
    final displayedThemes = allThemes
        .where((t) => t.isDark == _showDark)
        .toList();

    final themeState = ref.watch(themeServiceProvider);
    final activeTheme = themeState.activeTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header / Filter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Themes", style: Theme.of(context).textTheme.titleMedium),
            // Light/Dark Toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined, size: 16),
                ),
              ],
              selected: {_showDark},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _showDark = newSelection.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Theme Grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: displayedThemes.length,
            itemBuilder: (context, index) {
              final themeInfo = displayedThemes[index];
              final isSelected = activeTheme.id == themeInfo.id;

              // Preview Logic
              // If it's a fixed theme, use its primary color or background.
              // If it's custom, use the current seed color if selected, or default blue.
              Color seedPreview;
              Color bgPreview;

              if (themeInfo.supportCustomColor) {
                // For custom supported themes
                seedPreview = (isSelected && themeState.seedColor != null)
                    ? themeState.seedColor!
                    : Colors.blue;
                bgPreview = themeInfo.isDark ? Colors.black : Colors.white;
              } else {
                // Fixed themes
                final tData = themeInfo.fixedTheme!;
                seedPreview = tData.colorScheme.primary;
                bgPreview = tData.scaffoldBackgroundColor;
              }

              return InkWell(
                onTap: () {
                  ref.read(themeServiceProvider.notifier).setTheme(themeInfo);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgPreview,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Simple visual representation
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: seedPreview,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        themeInfo.name,
                        style: TextStyle(
                          color: themeInfo.isDark ? Colors.white : Colors.black,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Custom Color Picker Section
        if (activeTheme.supportCustomColor) ...[
          const Divider(),
          const SizedBox(height: 8),
          Text("Accent Color", style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final color in _presetColors)
                  _ColorOption(
                    color: color,
                    isSelected: themeState.seedColor?.value == color.value,
                    onTap: () {
                      ref
                          .read(themeServiceProvider.notifier)
                          .setSeedColor(color);
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static const _presetColors = [
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.amber,
    Color(0xFF0DFF1D), // Similar to Theme1
    Color(0xFFFC97FF), // Similar to Theme2
  ];
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                )
              : null,
          boxShadow: [
            if (isSelected) BoxShadow(color: Colors.black26, blurRadius: 4),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 16,
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    );
  }
}

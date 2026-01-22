import 'package:api_craft/features/settings/widgets/themes_settings_view.dart';
import 'package:api_craft/features/settings/widgets/ui_settings_view.dart';
import 'package:api_craft/features/themes/models/theme_model.dart';
import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _sections = [
    {
      'title': 'Themes',
      'icon': Icons.palette_outlined,
      'view': const ThemesSettingsView(),
    },
    {
      'title': 'UI',
      'icon': Icons.desktop_mac_outlined,
      'view': const UISettingsView(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Determine Dialog Size
    final size = MediaQuery.of(context).size;
    final width = 800.0;
    final height = 600.0;

    final theme = Theme.of(context);
    final sidebarTheme = theme.extension<SidebarTheme>()!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          children: [
            // Left Sidebar
            Container(
              width: 200,
              color: sidebarTheme.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Settings",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sections.length,
                      itemBuilder: (context, index) {
                        final section = _sections[index];
                        final isSelected = index == _selectedIndex;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          child: Container(
                            color: isSelected ? sidebarTheme.itemActive : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  section['icon'],
                                  size: 18,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.iconTheme.color,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  section['title'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : sidebarTheme.text,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
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
                ],
              ),
            ),

            // Vertical Divider
            VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),

            // Right Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _sections[_selectedIndex]['view'] as Widget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

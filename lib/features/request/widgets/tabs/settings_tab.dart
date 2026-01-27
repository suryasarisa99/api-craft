// ignore_for_file: depend_on_referenced_packages

import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/features/request/models/inherited_request_model.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/request/providers/request_details_provider.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/workspace/workspace_config_dialog.dart';
import 'package:api_craft/features/sidebar/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsTab extends ConsumerStatefulWidget {
  final String id;
  const SettingsTab({super.key, required this.id});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final debouncer = Debouncer(Duration(milliseconds: 500));

  @override
  Widget build(BuildContext context) {
    final nodeSettings = ref.watch(
      reqComposeProvider(widget.id).select((v) => v.node.config.settings),
    );

    final InheritedRequest inherited = ref.watch(
      requestDetailsProvider(widget.id).select((s) => s.inherit),
    );

    // Effective settings: Local if set, otherwise Inherited
    final effectiveSettings = nodeSettings ?? inherited.settings;
    final isInherited = nodeSettings == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Request Settings",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (isInherited)
                if (inherited.settingsSource != null)
                  TextButton.icon(
                    icon: const Icon(Icons.link, size: 16),
                    label: Text(
                      "Inherited from ${inherited.settingsSource!.name}",
                    ),
                    onPressed: () =>
                        _navigateToSource(context, inherited.settingsSource!),
                  )
                else
                  const Chip(label: Text("Default Settings"))
              else
                TextButton(
                  onPressed: () {
                    // Reset to inherit
                    ref
                        .read(reqComposeProvider(widget.id).notifier)
                        .updateRequestSettings(null);
                  },
                  child: const Text("Reset to Inherited"),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isInherited &&
              inherited.settingsSource == null &&
              nodeSettings == null)
            // Showing defaults, offer to customize?
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: OutlinedButton(
                onPressed: () {
                  // Start customizing with current defaults
                  _performUpdate(effectiveSettings);
                },
                child: const Text("Customize Settings"),
              ),
            ),

          if (isInherited && inherited.settingsSource != null)
            // Offer to Override
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: OutlinedButton(
                onPressed: () {
                  _performUpdate(effectiveSettings);
                },
                child: const Text("Override Settings"),
              ),
            ),

          // Fields (Disabled if inherited? No, user asked for "Inheritance or Override".
          // If Inherited, we should just show the values maybe read-only?)
          // "Click the btn automatically goes to settings" -> Implies read-only link.
          // So if isInherited, fields should be read-only or disabled.
          _buildField(
            context,
            "Follow Redirects",
            "Automatically follow HTTP redirects",
            Switch(
              value: effectiveSettings.followRedirects ?? true,
              onChanged: isInherited
                  ? null
                  : (val) {
                      _updateSettings(
                        effectiveSettings.copyWith(followRedirects: val),
                      );
                    },
            ),
          ),
          const Divider(),
          _buildField(
            context,
            "Max Redirects",
            "Maximum number of redirects to follow",
            SizedBox(
              width: 100,
              child: TextFormField(
                enabled: !isInherited,
                // Key is important to update when switching modes
                key: ValueKey(
                  "max_red_${isInherited}_${effectiveSettings.maxRedirects}",
                ),
                initialValue: effectiveSettings.maxRedirects?.toString() ?? '5',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  final intVal = int.tryParse(val);
                  if (intVal != null) {
                    _updateSettings(
                      effectiveSettings.copyWith(maxRedirects: intVal),
                      debounce: true,
                    );
                  }
                },
              ),
            ),
          ),
          const Divider(),
          _buildField(
            context,
            "Encode URL",
            "Automatically encode URL components",
            Switch(
              value: effectiveSettings.encodeUrl ?? true,
              onChanged: isInherited
                  ? null
                  : (val) {
                      _updateSettings(
                        effectiveSettings.copyWith(encodeUrl: val),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String title,
    String subtitle,
    Widget control,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        control,
      ],
    );
  }

  void _navigateToSource(BuildContext context, Node source) {
    final node = ref.read(fileTreeProvider).nodeMap[widget.id];
    if (node is FolderNode) {
      Navigator.of(context).pop();
    }

    if (source is WorkspaceNode) {
      showDialog(
        context: context,
        builder: (_) => WorkspaceConfigDialog(
          workspaceId: source.id,
          initialIndex: 3, // Settings Tab Index (Approx, check logic)
        ),
      );
    } else {
      showFolderConfigDialog(
        context: context,
        ref: ref,
        id: source.id,
        tabIndex: 6, // Settings Tab Index for Folder (Review this)
      );
    }
  }

  void _updateSettings(RequestSettings newSettings, {bool debounce = false}) {
    if (debounce) {
      debouncer.run(() {
        _performUpdate(newSettings);
      });
    } else {
      _performUpdate(newSettings);
    }
  }

  void _performUpdate(RequestSettings newSettings) {
    ref
        .read(reqComposeProvider(widget.id).notifier)
        .updateRequestSettings(newSettings);
  }
}

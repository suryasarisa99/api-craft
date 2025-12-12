// --- AUTH TAB ---
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/sidebar/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthTabHeader extends ConsumerStatefulWidget {
  final String id;
  const AuthTabHeader(this.id, {super.key});

  @override
  ConsumerState<AuthTabHeader> createState() => _AuthTabHeaderState();
}

class _AuthTabHeaderState extends ConsumerState<AuthTabHeader> {
  // helpers
  late final provider = resolveConfigProvider(widget.id);
  late final notifier = ref.read(provider.notifier);

  @override
  Widget build(BuildContext context) {
    final authType = ref.watch(
      provider.select((value) => value.node.config.auth.type),
    );
    Node? authSource;
    if (authType == AuthType.inherit) {
      authSource = ref.watch(
        provider.select((value) => value.effectiveAuthSource),
      );
    }
    return Tab(
      child: Text(
        authType == AuthType.inherit && authSource != null
            ? "${authSource.config.auth.type} (inherit)"
            : authType.toString(),
      ),
    );
  }
}

class AuthTab extends ConsumerWidget {
  final String id;
  const AuthTab({required this.id, super.key});

  ResolveConfigNotifier notifier(WidgetRef ref) =>
      ref.read(resolveConfigProvider(id).notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(
      resolveConfigProvider(id).select((value) => value.node.config.auth),
    );
    final node = ref.read(fileTreeProvider).nodeMap[id]!;
    final authSource = ref.watch(
      resolveConfigProvider(id).select((value) => value.effectiveAuthSource),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<AuthType>(
            decoration: const InputDecoration(
              labelText: "Auth Type",
              border: OutlineInputBorder(),
            ),
            initialValue: auth.type,
            items: AuthType.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (type) {
              if (type != null) {
                notifier(ref).updateAuth(auth.copyWith(type: type));
              }
            },
          ),
        ),
        if (auth.type == AuthType.inherit)
          Expanded(
            child: Center(
              child: Row(
                children: [
                  Text(
                    "auth type:  ${auth.type.name} from ${authSource?.name}",
                  ),
                  const SizedBox(width: 8),
                  if (authSource != null)
                    TextButton(
                      onPressed: () {
                        if (node is FolderNode) {
                          // aldready we opened folder dialog
                          // so close it first
                          Navigator.of(context).pop();
                        }
                        showFolderConfigDialog(
                          context: context,
                          ref: ref,
                          node: authSource as FolderNode,
                        );
                      },
                      child: Text(authSource.name),
                    ),
                ],
              ),
            ),
          )
        else if (auth.type == AuthType.noAuth)
          const Expanded(child: Center(child: Text("No Authentication")))
        else
          // Show fields for Basic/Bearer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (auth.type == AuthType.bearer)
                  TextFormField(
                    initialValue: auth.token,
                    decoration: const InputDecoration(labelText: "Token"),
                    onChanged: (v) =>
                        notifier(ref).updateAuth(auth.copyWith(token: v)),
                  ),
                // Add Basic Auth fields...
              ],
            ),
          ),
      ],
    );
  }
}

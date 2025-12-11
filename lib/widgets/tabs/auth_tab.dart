// --- AUTH TAB ---
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/sidebar/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthTapHeader extends ConsumerStatefulWidget {
  final EditorParams params;
  const AuthTapHeader(this.params, {super.key});

  @override
  ConsumerState<AuthTapHeader> createState() => _AuthTapHeaderState();
}

class _AuthTapHeaderState extends ConsumerState<AuthTapHeader> {
  // helpers
  late final provider = resolveConfigProvider(widget.params);
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
  final EditorParams params;
  const AuthTab({required this.params, super.key});

  ResolveConfigNotifier notifier(WidgetRef ref) =>
      ref.read(resolveConfigProvider(params).notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(
      resolveConfigProvider(params).select((value) => value.node.config.auth),
    );
    final authSource = ref.watch(
      resolveConfigProvider(
        params,
      ).select((value) => value.effectiveAuthSource),
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
                        if (params.node is FolderNode) {
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

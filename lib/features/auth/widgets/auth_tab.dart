import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/auth/auth_registry.dart';
import 'package:api_craft/features/collection/collection_config_dialog.dart';
import 'package:api_craft/features/dynamic-form/form_state.dart';
import 'package:api_craft/features/sidebar/context_menu.dart';
import 'package:api_craft/features/dynamic-form/dynamic_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthTab extends ConsumerWidget {
  final String id;
  const AuthTab({required this.id, super.key});

  ReqComposeNotifier notifier(WidgetRef ref) =>
      ref.read(reqComposeProvider(id).notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(
      reqComposeProvider(id).select((value) => value.node.config.auth),
    );

    final authSource = ref.watch(
      reqComposeProvider(id).select((value) => value.authSource),
    );
    return Column(
      children: [
        if (auth.type == AuthType.inherit)
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: .center,
                children: [
                  if (authSource != null)
                    TextButton(
                      onPressed: () {
                        final node = ref.read(fileTreeProvider).nodeMap[id];
                        if (node is FolderNode) {
                          // aldready we opened folder dialog
                          // so close it first
                          Navigator.of(context).pop();
                        }
                        if (authSource.parentId == null) {
                          showDialog(
                            context: context,
                            builder: (_) => CollectionConfigDialog(
                              collectionId: authSource.id,
                            ),
                          );
                        } else {
                          showFolderConfigDialog(
                            context: context,
                            ref: ref,
                            id: authSource.id,
                            tabIndex: 2,
                          );
                        }
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
                AuthTabContent(
                  key: ValueKey(auth.type),
                  id: id,
                  authType: auth.type,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AuthTabContent extends ConsumerStatefulWidget {
  final String id;
  final AuthType authType;
  const AuthTabContent({super.key, required this.id, required this.authType});

  @override
  ConsumerState<AuthTabContent> createState() => _AuthTabContentState();
}

class _AuthTabContentState extends ConsumerState<AuthTabContent> {
  late final authentication = getAuth(widget.authType)!;
  late final s = getFnState(authentication.args, {});

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicForm(
      inputs: authentication.args,
      onChanged: (v, _) {},
      data: s,
      id: widget.id,
    );
  }
}

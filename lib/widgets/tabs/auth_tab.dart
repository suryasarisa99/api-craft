// --- AUTH TAB ---
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/sidebar/context_menu.dart';
import 'package:api_craft/widgets/ui/custom_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _authsTypes = [
  AuthType.apiKey,
  AuthType.awsSignature,
  AuthType.basic,
  AuthType.bearer,
  AuthType.jwtBearer,
  AuthType.oAuth1,
  AuthType.oAuth2,
  AuthType.ntlm,
];

class AuthTabHeader extends ConsumerStatefulWidget {
  final String id;
  final TabController? controller;
  final VoidCallback? handleSetTab;
  final bool? isTabActive;
  final Color? color;
  const AuthTabHeader(
    this.id, {
    super.key,
    // for request
    this.controller,

    // for folder
    this.isTabActive,
    this.handleSetTab,
    this.color,
  });

  @override
  ConsumerState<AuthTabHeader> createState() => _AuthTabHeaderState();
}

class _AuthTabHeaderState extends ConsumerState<AuthTabHeader> {
  // helpers
  late final provider = resolveConfigProvider(widget.id);
  late final notifier = ref.read(provider.notifier);
  final popupKey = GlobalKey<CustomPopupState>();
  late bool isTabActive = widget.isTabActive ?? widget.controller?.index == 3;

  @override
  void initState() {
    super.initState();

    widget.controller?.addListener(() {
      debugPrint("index: ${widget.controller?.index}");
      if (widget.controller?.index == 3) {
        setState(() {
          isTabActive = true;
        });
      } else {
        setState(() {
          isTabActive = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AuthTabHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive != null &&
        widget.isTabActive != oldWidget.isTabActive) {
      isTabActive = widget.isTabActive!;
    }
  }

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
    final style = TextStyle(color: widget.color);
    return Tab(
      child: GestureDetector(
        onTap: () {
          if (!isTabActive) {
            debugPrint("navigating to auth tab");
            if (widget.controller != null) {
              widget.controller?.animateTo(3);
            } else {
              widget.handleSetTab?.call();
            }
          } else {
            debugPrint("showing auth menu");
            popupKey.currentState?.show();
          }
        },
        child: AbsorbPointer(
          child: MyCustomMenu.contentColumn(
            // width: 100,
            items: [
              ..._authsTypes.map(
                (type) => _buildAuthOption(type, checked: authType == type),
              ),
              SizedBox(child: Divider(height: 12, thickness: 1)),
              _buildAuthOption(
                AuthType.noAuth,
                checked: authType == AuthType.noAuth,
              ),
              _buildAuthOption(
                AuthType.inherit,
                checked: authType == AuthType.inherit,
              ),

              // if (authType == AuthType.inherit && authSource != null)
            ],
            popupKey: popupKey,
            child: Row(
              children: [
                if (authType == AuthType.inherit && authSource != null) ...[
                  Text(authSource.config.auth.type.title, style: style),
                  SizedBox(width: 4),
                  Icon(Icons.brush, size: 14),
                ] else
                  Text(authType.title, style: style),
                SizedBox(width: 4),
                if (widget.controller == null) Spacer(),
                Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthOption(AuthType type, {bool checked = false}) {
    final n = type.title[0].toUpperCase() + type.title.substring(1);
    return SizedBox(
      width: 180,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          ref
              .read(resolveConfigProvider(widget.id).notifier)
              .updateAuth(
                ref
                    .read(resolveConfigProvider(widget.id))
                    .node
                    .config
                    .auth
                    .copyWith(type: type),
              );
          Navigator.of(context).pop();
        },
        child: Ink(
          padding: const .symmetric(vertical: 3, horizontal: 4),
          // alignment: Alignment.centerLeft,
          width: 140,
          child: Row(
            children: [
              if (checked)
                Icon(
                  Icons.check,
                  color: const Color.fromARGB(255, 120, 120, 120),
                  size: 16,
                )
              else
                SizedBox(width: 16),
              SizedBox(width: 8),
              Text(n),
            ],
          ),
        ),
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
        if (auth.type == AuthType.inherit)
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: .center,
                children: [
                  Text("No Authentication"),
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

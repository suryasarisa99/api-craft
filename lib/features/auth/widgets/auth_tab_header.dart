import 'package:api_craft/features/request/providers/req_compose_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';

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
  final VoidCallback? handleSetTab;
  final bool isTabActive;
  final bool isFolder;
  final Color? color;
  const AuthTabHeader(
    this.id, {
    super.key,
    required this.isTabActive,
    this.handleSetTab,
    this.isFolder = true,

    // for folder
    this.color,
  });

  @override
  ConsumerState<AuthTabHeader> createState() => _AuthTabHeaderState();
}

class _AuthTabHeaderState extends ConsumerState<AuthTabHeader> {
  // helpers
  late final provider = reqComposeProvider(widget.id);
  late final notifier = ref.read(provider.notifier);
  final popupKey = GlobalKey<CustomPopupState>();

  late bool isTabActive = widget.isTabActive;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant AuthTabHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive != oldWidget.isTabActive) {
      isTabActive = widget.isTabActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authType = ref.watch(
      provider.select((value) => value.node.config.auth.type),
    );
    Node? authSource;
    if (authType == AuthType.inherit) {
      authSource = ref.watch(provider.select((value) => value.authSource));
    }
    final style = TextStyle(color: widget.color);
    return GestureDetector(
      onTap: () {
        debugPrint('isTabActive: $isTabActive');
        if (!isTabActive) {
          debugPrint("navigating to auth tab");
          widget.handleSetTab?.call();
        } else {
          debugPrint("showing auth menu");
          popupKey.currentState?.show();
        }
      },
      child: AbsorbPointer(
        child: MyCustomMenu.contentColumn(
          items: [
            ..._authsTypes.map(
              (type) => _buildAuthOption(type, checked: authType == type),
            ),
            menuDivider,
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
          useBtn: false,
          child: Tab(
            child: Row(
              children: [
                if (authType == AuthType.inherit && authSource != null) ...[
                  Text(authSource.config.auth.type.title, style: style),
                  SizedBox(width: 4),
                  Icon(Icons.brush, size: 14),
                ] else
                  Text(authType.label, style: style),
                SizedBox(width: 4),
                if (widget.isFolder) Spacer(),
                Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthOption(AuthType type, {bool checked = false}) {
    final n = type.title[0].toUpperCase() + type.title.substring(1);
    return CustomMenuIconItem.tick(
      checked: checked,
      title: Text(n),
      value: type.name,
      onTap: (v) {
        final auth = ref
            .read(reqComposeProvider(widget.id))
            .node
            .config
            .auth
            .copyWith(type: type);
        notifier.updateAuth(auth);
      },
    );
  }
}

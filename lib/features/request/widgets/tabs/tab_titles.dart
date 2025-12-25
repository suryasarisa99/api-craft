import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/features/request/models/node_config_model.dart';
import 'package:api_craft/features/request/providers/req_compose_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const wsBodyTypes = {"json": "Json", "xml": "Xml", "text": "Text"};

class WsBodyHeader extends ConsumerWidget {
  final GlobalKey<CustomPopupState> popupKey;
  final String id;
  const WsBodyHeader({super.key, required this.id, required this.popupKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? bodyType = ref.watch(
      reqComposeProvider(
        id,
      ).select((d) => (d.node.config as RequestNodeConfig).bodyType),
    );
    String? displayMssg;
    if (bodyType == null || bodyType == "text") {
      displayMssg = "Message";
    } else {
      displayMssg = wsBodyTypes[bodyType]!;
    }
    return IgnorePointer(
      child: MyCustomMenu.contentColumn(
        popupKey: popupKey,
        useBtn: false,
        items: wsBodyTypes.keys
            .map(
              (e) => CustomMenuIconItem.tick(
                title: Text(wsBodyTypes[e]!),
                value: e,
                checked: bodyType == e,
                onTap: (v) =>
                    ref.read(reqComposeProvider(id).notifier).updateBodyType(v),
              ),
            )
            .toList(),
        child: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayMssg),
              const Icon(Icons.arrow_drop_down, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

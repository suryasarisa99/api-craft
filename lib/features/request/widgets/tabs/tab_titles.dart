import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/features/request/models/node_config_model.dart';
import 'package:api_craft/features/request/providers/req_compose_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BodyType {
  static const noBody = "No Body";
  static const formUrlEncoded = "URL-Encoded";
  static const formMultipart = "Multipart";
  static const json = "JSON";
  static const text = "Text";
  static const xml = "XML";
  static const binaryFile = "Binary File";
}

class BodyHeader extends ConsumerWidget {
  final GlobalKey<CustomPopupState> popupKey;
  final String id;
  const BodyHeader({super.key, required this.id, required this.popupKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formReleated = [BodyType.formUrlEncoded, BodyType.formMultipart];
    final textReleated = [BodyType.json, BodyType.xml, BodyType.text];
    final otherReleated = [BodyType.binaryFile, BodyType.noBody];
    final currBodyType = ref.watch(
      reqComposeProvider(
        id,
      ).select((d) => (d.node.config as RequestNodeConfig).bodyType),
    );
    return IgnorePointer(
      child: MyCustomMenu.contentColumn(
        popupKey: popupKey,
        useBtn: false,
        items: [
          LabeledDivider(text: "Form Data"),
          ...buildMenuItems(formReleated, currBodyType, ref),
          LabeledDivider(text: "Text Content"),
          ...buildMenuItems(textReleated, currBodyType, ref),
          LabeledDivider(text: "Other"),
          ...buildMenuItems(otherReleated, currBodyType, ref),
        ],
        child: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currBodyType == BodyType.noBody ? "Body" : currBodyType ?? '',
              ),
              const Icon(Icons.arrow_drop_down, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> buildMenuItems(List<String> items, String? curr, WidgetRef ref) {
    return items
        .map(
          (e) => CustomMenuIconItem.tick(
            title: Text(e),
            value: e,
            checked: curr == e,
            onTap: (v) =>
                ref.read(reqComposeProvider(id).notifier).updateBodyType(v),
          ),
        )
        .toList();
  }
}

// const wsBodyTypes = {"json": "Json", "xml": "Xml", "text": "Text"};
const wsBodyTypes = [BodyType.json, BodyType.xml, BodyType.text];

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
    debugPrint("bodyType: $bodyType");
    String? displayMssg;
    if (bodyType == null || bodyType == BodyType.text) {
      displayMssg = "Message";
    } else {
      displayMssg = bodyType;
    }
    return IgnorePointer(
      child: MyCustomMenu.contentColumn(
        popupKey: popupKey,
        useBtn: false,
        items: wsBodyTypes
            .map(
              (e) => CustomMenuIconItem.tick(
                title: Text(e),
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

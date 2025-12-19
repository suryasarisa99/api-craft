import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/key_value_editor.dart';
import 'package:flutter/material.dart';

class HeadersTab extends StatelessWidget {
  final String id;
  const HeadersTab({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    debugPrint("building::: Headers Tab");
    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        children: [
          // Read-Only Inherited
          InheritedHeaders(id: id),

          // Editable Headers
          Consumer(
            builder: (context, ref, _) {
              final headers = ref.watch(
                reqComposeProvider(
                  id,
                ).select((value) => value.node.config.headers),
              );
              return Expanded(
                child: KeyValueEditor(
                  id: id,
                  mode: KeyValueEditorMode.headers,
                  items: List.from(
                    headers,
                  ), // Pass copy to allow local reordering
                  onChanged: (newItems) {
                    ref
                        .read(reqComposeProvider(id).notifier)
                        .updateHeaders(newItems);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class InheritedHeaders extends ConsumerWidget {
  final String id;
  const InheritedHeaders({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inheritedHeaders = ref.watch(
      reqComposeProvider(id).select((value) => value.inheritedHeaders),
    );
    if (inheritedHeaders.isEmpty) {
      return SizedBox.shrink();
    }
    return Padding(
      padding: const .only(bottom: 16, left: 16, right: 16),
      child: ExpansionTile(
        tilePadding: .symmetric(horizontal: 12, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,

        backgroundColor: const Color(0xFF252525),
        collapsedBackgroundColor: const Color(0xFF252525),
        visualDensity: VisualDensity.compact,
        minTileHeight: 28,
        maintainState: true,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.hardEdge,
        title: Text("Inherited Headers (${inheritedHeaders.length})"),
        children: [
          ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 12,
              top: 0,
            ),
            itemCount: inheritedHeaders.length,
            itemExtent: 36,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (ctx, i) {
              final h = inheritedHeaders[i];
              return Row(
                children: [
                  Icon(
                    h.isEnabled
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: const Color.fromARGB(255, 102, 102, 102),
                  ),
                  const SizedBox(width: 8),
                  buildItem(h.key),
                  const SizedBox(width: 8),
                  buildItem(h.value),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildItem(String v) {
    return Expanded(
      //selectable text
      child: Container(
        padding: .symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color.fromARGB(255, 67, 67, 67)),
          color: const Color.fromARGB(255, 40, 40, 40),
        ),
        child: SelectableText(
          v,
          style: const TextStyle(color: Color.fromARGB(255, 150, 150, 150)),
        ),
      ),
    );
  }
}

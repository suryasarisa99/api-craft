import 'package:api_craft/screens/home/folder/folder_editor_controller.dart';
import 'package:api_craft/widgets/ui/key_value_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show RectangleBorder;

class HeadersTab extends StatelessWidget {
  final FolderEditorController controller;
  const HeadersTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Read-Only Inherited
          if (controller.inheritedHeaders.isNotEmpty)
            ExpansionTile(
              tilePadding: .symmetric(horizontal: 12, vertical: 0),
              childrenPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,

              backgroundColor: const Color(0xFF252525),
              collapsedBackgroundColor: const Color(0xFF252525),
              visualDensity: VisualDensity.compact,
              minTileHeight: 28,
              maintainState: true,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.hardEdge,
              title: Text(
                "Inherited Headers (${controller.inheritedHeaders.length})",
              ),
              children: [
                ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    top: 0,
                  ),
                  itemCount: controller.inheritedHeaders.length,
                  itemExtent: 36,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (ctx, i) {
                    final h = controller.inheritedHeaders[i];
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
                        Expanded(
                          //selectable text
                          child: Container(
                            padding: .symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color.fromARGB(255, 67, 67, 67),
                              ),
                              color: const Color.fromARGB(255, 40, 40, 40),
                            ),
                            child: SelectableText(
                              h.key,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 150, 150, 150),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          //selectable text
                          child: Container(
                            padding: .symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color.fromARGB(255, 67, 67, 67),
                              ),
                              color: const Color(0xFF2C2C28),
                            ),
                            child: SelectableText(
                              h.value,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 150, 150, 150),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          SizedBox(height: 16),
          Expanded(
            child: KeyValueEditor(
              mode: KeyValueEditorMode.headers,
              items: List.from(
                controller.node.config.headers,
              ), // Pass copy to allow local reordering
              onChanged: (newItems) => controller.updateHeaders(newItems),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/flows/filter/condition_provider.dart';
import 'package:api_craft/flows/filter/widgets/filter_group.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class FilterPopup extends ConsumerWidget {
  final FilterManagerProvider filterManager;
  final String title;

  const FilterPopup({
    super.key,
    required this.filterManager,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final manager = ref.watch(filterManager);

    final filterWidget = FilterGroupWidget(
      group: manager.rootFilter,
      managerProvider: filterManager,
      isRoot: true,
      index: 0,
    );
    return CustomDialog(
      width: 900,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const .only(left: 12, top: 8),
            child: Text(
              title[0].toUpperCase() + title.substring(1),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(child: filterWidget),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

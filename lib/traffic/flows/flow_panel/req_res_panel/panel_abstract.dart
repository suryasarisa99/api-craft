import 'package:api_craft/traffic/flows/flow_panel/req_res_panel/panel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';
import 'package:multi_split_view/multi_split_view.dart';

abstract class PanelAbstract extends StatefulWidget {
  const PanelAbstract({required this.resizeController, super.key});
  final MultiSplitViewController resizeController;

  @override
  State<PanelAbstract> createState();
}

abstract class PanelAbstractState extends State<PanelAbstract>
    with SingleTickerProviderStateMixin {
  // need to ovveride in subclass
  String get title;
  int get tabsLen;
  List<Widget> buildViews();
  AbstractPanelTitles get panelTitles;

  // declarations
  late final tabIndex = ValueNotifier<int>(0);
  late TabController tabController = TabController(
    length: tabsLen,
    vsync: this,
  );
  late var views = buildViews();

  @override
  void initState() {
    super.initState();
    tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    tabIndex.value = tabController.index;
    setState(() {});

    // final previewBodyState = _previewBodyKey.currentState;
    // if (previewBodyState == null) return;

    // // Enable/disable listening based on whether we're on preview body tab
    // if (tabController.index == previewBodyTabIndex) {
    //   previewBodyState.resumeListening();
    // } else {
    //   previewBodyState.pauseListening();
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          // codeControllerService: codeControllerService,
          resizeController: widget.resizeController,
          tabController: tabController,
          tabIndex: tabIndex,
          title: title,
          panelTabs: panelTitles,
        ),
        Expanded(
          child: Padding(
            padding: .zero,
            child: LazyLoadIndexedStack(
              // key: ValueKey(widget.id),
              index: tabController.index,
              preloadIndexes: [],
              autoDisposeIndexes: [],
              children: views,
            ),
          ),
        ),
      ],
    );
  }
}

abstract class AbstractPanelTitles extends ConsumerWidget {
  const AbstractPanelTitles({super.key, required this.tabController});

  final TabController tabController;

  /// Subclasses must implement this to provide a list of tabs.
  /// Each tab is represented as a `String` label.
  List<String> buildTabLabels(WidgetRef ref);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabLabels = buildTabLabels(ref);

    return TabBar(
      controller: tabController,
      isScrollable: true,
      dividerHeight: 0,
      tabAlignment: TabAlignment.start,
      unselectedLabelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      labelStyle: const TextStyle(fontSize: 13),
      tabs: [for (final label in tabLabels) Tab(text: label)],
    );
  }
}

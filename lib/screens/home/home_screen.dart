import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/request/request.dart';
import 'package:api_craft/screens/home/response/response_tab.dart';
import 'package:api_craft/screens/home/sidebar/sidebar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(
        id: 1,
        min: 2,
        size: 250,
        builder: (context, area) => const FileExplorerView(),
      ),
      Area(id: 2, flex: 1, builder: (_, _) => const ReqTabWrapper()),
      Area(id: 3, flex: 1, builder: (context, area) => const ResponseTAb()),
      // Area(id: 1, min: 2, size: 250, data: 'side-bar'),
      // Area(id: 2, flex: 1, data: 'request-tab'),
      // Area(id: 3, flex: 1, data: 'response-tab'),
    ],
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final sidebarWidth = _controller.areas[0].size;
      final reqFlex = _controller.areas[1].flex;
      final resFlex = _controller.areas[2].flex;
      debugPrint(
        "Sidebar width: $sidebarWidth, Req flex: $reqFlex, Res flex: $resFlex",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const HomeTopBar(),
          // Expanded(child: MultiSplitView(controller: _controller)),
          Expanded(
            child: MultiSplitViewTheme(
              data: MultiSplitViewThemeData(
                dividerThickness: 1,
                dividerHandleBuffer:
                    MultiSplitViewThemeData.defaultDividerHandleBuffer + 4,
                dividerPainter: DividerPainters.background(
                  color: const Color.fromARGB(255, 57, 57, 57),
                  highlightedColor: const Color.fromARGB(255, 92, 92, 92),
                ),
              ),
              child: MultiSplitView(
                controller: _controller,
                // builder: (context, area) {
                //   switch (area.data) {
                //     case 'side-bar':
                //       return const FileExplorerView();
                //     case 'request-tab':
                //       return const ReqTabWrapper();
                //     case 'response-tab':
                //       return const ResponseTAb();
                //     default:
                //       return const SizedBox.shrink();
                //   }
                // },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeTopBar extends ConsumerStatefulWidget {
  const HomeTopBar({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends ConsumerState<HomeTopBar> {
  @override
  Widget build(BuildContext context) {
    final selectedCollection = ref.watch(selectedCollectionProvider);
    return Row(
      children: [
        Text(
          selectedCollection != null
              ? 'Selected Collection: ${selectedCollection.name}'
              : 'No Collection Selected',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

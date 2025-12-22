import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/collection/collection_picker.dart';
import 'package:api_craft/features/environment/environment_picker.dart';
import 'package:api_craft/features/request/widgets/request.dart';
import 'package:api_craft/features/response/response_tab.dart';
import 'package:api_craft/features/sidebar/sidebar.dart';
import 'package:api_craft/core/widgets/ui/top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'package:suryaicons/duotone_rounded.dart';
import 'package:suryaicons/twotone_rounded.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool isSidebarAutoClosed = false;
  bool isSidebarManuallyClosed = false;
  bool get isSidebarVisible => !isSidebarAutoClosed && !isSidebarManuallyClosed;
  static const double sidebarThresholdWidth = 800;
  static double windowWidth = 1000;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  static const sideBarWidget = FileExplorerView();
  final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(id: 1, min: 2, size: 250, data: 'side-bar'),
      Area(id: 2, flex: 1, data: 'request-tab'),
      Area(id: 3, flex: 1, data: 'response-tab'),
    ],
  );

  @override
  void initState() {
    super.initState();

    // Todo:  persist sidebar state and sizes
    _controller.addListener(() {
      final sidebarWidth = _controller.areas[0].size;
      final reqFlex = _controller.areas[1].flex;
      final resFlex = _controller.areas[2].flex;

      debugPrint(
        "Sidebar width: $sidebarWidth, Req flex: $reqFlex, Res flex: $resFlex",
      );
    });

    WidgetsBinding.instance.addObserver(this);
    _handleSizeChange();
  }

  @override
  void didChangeMetrics() {
    _handleSizeChange();
  }

  void _handleSizeChange() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final width = view.physicalSize.width / view.devicePixelRatio;
    windowWidth = width;

    if (width < sidebarThresholdWidth && isSidebarVisible) {
      // small window + sidebar shows => auto close sidebar
      isSidebarAutoClosed = true;
      _controller.areas[0].size = 0;
      setState(() {});
    } else if (width >= sidebarThresholdWidth && isSidebarAutoClosed) {
      // large window + sidebar auto closed => reopen sidebar
      isSidebarAutoClosed = false;
      // close scaffold may be if opened
      scaffoldKey.currentState?.closeDrawer();
      _controller.areas[0].size = 250;
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("HomeScreen rebuild");
    return Scaffold(
      key: scaffoldKey,
      drawer: Container(
        color: const Color.fromARGB(255, 32, 29, 32),
        padding: const EdgeInsets.only(top: 30),
        child: SizedBox(width: 300, child: sideBarWidget),
      ),
      body: Column(
        children: [
          // const HomeTopBar(),
          TopBar(
            right: [],
            left: [
              IconButton(
                onPressed: () {
                  final smallWindow = windowWidth < sidebarThresholdWidth;
                  if (isSidebarVisible) {
                    // sidebar shows
                    isSidebarManuallyClosed = true;
                    _controller.areas[0].size = 0;
                  } else {
                    // sidebar closed
                    if (smallWindow) {
                      // use drawer for small window
                      scaffoldKey.currentState?.openDrawer();
                    } else {
                      isSidebarManuallyClosed = false;
                      _controller.areas[0].size = 250;
                    }
                  }
                  setState(() {});
                },
                // icon: Icon(
                //   isSidebarVisible ? Icons.chevron_left : Icons.chevron_right,
                // ),
                icon: isSidebarVisible
                    ? const SuryaThemeIcon(BulkRounded.sidebarLeft01)
                    : const SuryaThemeIcon(BulkRounded.sidebarLeft),
              ),
              CollectionPicker(),
              // > indicator?
              const Text(" > ", style: TextStyle(color: Colors.grey)),
              const EnvironmentPicker(),
            ],
          ),
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
                builder: (context, area) {
                  switch (area.data) {
                    case 'side-bar':
                      // return const FileExplorerView();
                      return sideBarWidget;
                    case 'request-tab':
                      return const ReqTabWrapper();
                    case 'response-tab':
                      return const ResponseTAb();
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/collection/collection_picker.dart';
import 'package:api_craft/features/environment/environment_picker.dart';
import 'package:api_craft/features/request/widgets/request.dart';
import 'package:api_craft/features/response/response_tab.dart';
import 'package:api_craft/features/sidebar/sidebar.dart';
import 'package:api_craft/core/widgets/ui/top_bar.dart';
import 'package:flutter/services.dart';
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
  static const double sidebarMinWidth = 5;
  static const double sidebarThresholdWidth = 800;
  static double windowWidth = 1200;
  static double sidebarInitialWidth = 250;

  bool isSidebarAutoClosed = false;
  bool isSidebarManuallyClosed = prefs.getBool('sidebar_closed') ?? false;
  bool get isSidebarVisible => !isSidebarAutoClosed && !isSidebarManuallyClosed;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  static const sideBarWidget = FileExplorerView();
  final debouncer = Debouncer(Duration(milliseconds: 500));

  late final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(
        id: 1,
        min: sidebarMinWidth,
        size: getInitialSidebarWidth(),
        data: 'side-bar',
      ),
      Area(
        id: 2,
        flex: prefs.getDouble('request_flex') ?? 1,
        data: 'request-tab',
      ),
      Area(
        id: 3,
        flex: prefs.getDouble('response_flex') ?? 1,
        data: 'response-tab',
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_listener);
    WidgetsBinding.instance.addObserver(this);
    final hk = HardwareKeyboard.instance;
    hk.addHandler((event) {
      if (event is KeyUpEvent) return false;
      final ctrl = hk.isMetaPressed || hk.isControlPressed;
      if (ctrl && event.logicalKey == LogicalKeyboardKey.keyB) {
        debugPrint('Sidebar toggle');
        toggleSidebar();
        return true;
      }
      return false;
    });
    _handleAutoToggleSidebar();
  }

  @override
  void didChangeMetrics() {
    _handleAutoToggleSidebar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _listener() {
    final sidebarWidth = _controller.areas[0].size ?? 0;
    final reqFlex = _controller.areas[1].flex;
    final resFlex = _controller.areas[2].flex;

    // key distinction: isSidebarVisible is TRUE during drag-to-close, but FALSE during toggle-close (checked before listener)
    // Actually toggle sets manual=true immediately, so isSidebarVisible becomes false.
    // So if width is small AND isSidebarVisible is true => It's a drag event.
    final isDragClose =
        sidebarWidth < (sidebarMinWidth + 2) && isSidebarVisible;

    debouncer.run(() {
      prefs.setDouble('sidebar_width', sidebarWidth);
      prefs.setDouble('request_flex', reqFlex ?? 1);
      prefs.setDouble('response_flex', resFlex ?? 1);

      if (isDragClose) {
        // User dragged to close -> Open should reset to default (250)
        prefs.remove('last_valid_sidebar_width');
        prefs.setBool('sidebar_closed', true);
      } else {
        // Normal state or Toggle Close
        if (sidebarWidth > 100) {
          prefs.setDouble('last_valid_sidebar_width', sidebarWidth);
        }

        if (sidebarWidth < sidebarMinWidth + 2) {
          prefs.setBool('sidebar_closed', true);
        } else {
          prefs.setBool('sidebar_closed', false);
        }
      }
    });

    if (sidebarWidth < (sidebarMinWidth + 2) && isSidebarVisible) {
      setState(() {
        isSidebarManuallyClosed = true;
      });
    } else if (sidebarWidth > sidebarMinWidth + 2 && isSidebarManuallyClosed) {
      setState(() {
        isSidebarManuallyClosed = false;
      });
    }

    debugPrint(
      "Sidebar width: $sidebarWidth, Req flex: $reqFlex, Res flex: $resFlex",
    );
  }

  void _handleAutoToggleSidebar() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final width = view.physicalSize.width / view.devicePixelRatio;
    windowWidth = width;

    if (width < sidebarThresholdWidth && isSidebarVisible) {
      // small window + sidebar shows => auto close sidebar
      isSidebarAutoClosed = true;
      closeSidebar();
      setState(() {});
    } else if (width >= sidebarThresholdWidth) {
      // large window + sidebar auto closed => reopen sidebar
      if (isSidebarAutoClosed) {
        isSidebarAutoClosed = false;
      }
      // close scaffold may be if opened
      scaffoldKey.currentState?.closeDrawer();
      openSidebar();
      setState(() {});
    }
  }

  void closeSidebar() {
    setState(() {
      _controller.areas[0].size = 0;
    });
    prefs.setDouble('sidebar_width', 0);
    prefs.setBool('sidebar_closed', true);
  }

  void openSidebar() {
    double restoreWidth =
        prefs.getDouble('last_valid_sidebar_width') ?? sidebarInitialWidth;
    if (restoreWidth < 100) {
      restoreWidth = sidebarInitialWidth;
    }

    setState(() {
      _controller.areas[0].size = restoreWidth;
    });
    prefs.setDouble('sidebar_width', restoreWidth);
    prefs.setBool('sidebar_closed', false);

    // Also reset last valid if we just defaulted? No, keeping it is fine.
  }

  double getInitialSidebarWidth() {
    if (isSidebarManuallyClosed) {
      return 0;
    }
    // Restoration logic on startup
    double width = prefs.getDouble('sidebar_width') ?? sidebarInitialWidth;

    // If it was somehow saved as 0 but NOT marked as closed check last valid
    if (width < 50) {
      // Try to recover
      width =
          prefs.getDouble('last_valid_sidebar_width') ?? sidebarInitialWidth;
    }

    if (width < 50) width = sidebarInitialWidth;

    return width;
  }

  void toggleSidebar() {
    final smallWindow = windowWidth < sidebarThresholdWidth;

    bool isDrawerOpen = scaffoldKey.currentState?.isDrawerOpen ?? false;
    if (isDrawerOpen) {
      scaffoldKey.currentState?.closeDrawer();
      return;
    }

    if (isSidebarVisible) {
      // sidebar shows
      isSidebarManuallyClosed = true;
      _controller.areas[0].size = 0;
      prefs.setBool('sidebar_closed', true);
      scaffoldKey.currentState?.closeDrawer();
    } else {
      // sidebar closed
      if (smallWindow) {
        // use drawer for small window
        scaffoldKey.currentState?.openDrawer();
      } else {
        openSidebar();
        isSidebarManuallyClosed = false;
        prefs.setBool('sidebar_closed', false);
      }
    }
    setState(() {});
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
                onPressed: toggleSidebar,
                // icon: Icon(
                //   isSidebarVisible ? Icons.chevron_left : Icons.chevron_right,
                // ),
                icon: isSidebarVisible
                    ? const SuryaThemeIcon(BulkRounded.sidebarLeft01)
                    : const SuryaThemeIcon(BulkRounded.sidebarLeft),
              ),
              CookiesJarPicker(),
              CollectionPicker(),
              Icon(Icons.keyboard_arrow_right, size: 16),
              const EnvironmentButton(),
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

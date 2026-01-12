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
import 'package:api_craft/features/panel/bottom_panel.dart';
import 'package:api_craft/features/panel/status_bar.dart';
import 'package:api_craft/features/panel/panel_state_provider.dart';
import 'package:suryaicons/bulk_rounded.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const double sidebarMinWidth = 5;
  static const double sidebarThresholdWidth = 1000;
  static double windowWidth = 1000;
  static double sidebarInitialWidth = 250;

  bool isSidebarAutoClosed = false;
  bool isSidebarManuallyClosed = prefs.getBool('sidebar_closed') ?? false;
  bool get isSidebarVisible => !isSidebarAutoClosed && !isSidebarManuallyClosed;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  static const sideBarWidget = FileExplorerView();
  final debouncer = Debouncer(Duration(milliseconds: 500));

  late final MultiSplitViewController _rootController =
      MultiSplitViewController(
        areas: [
          Area(
            id: 1,
            min: sidebarMinWidth,
            size: getInitialSidebarWidth(),
            data: 'side-bar',
          ),
          Area(id: 2, flex: 1, data: 'main-content'),
        ],
      );

  late final MultiSplitViewController _verticalController =
      MultiSplitViewController(
        areas: [
          Area(data: 'content', flex: 1),
          Area(data: 'bottom-panel', size: 0),
        ],
      );

  late final MultiSplitViewController _reqResController =
      MultiSplitViewController(
        areas: [
          Area(data: 'request-tab', flex: prefs.getDouble('request_flex') ?? 1),
          Area(
            data: 'response-tab',
            flex: prefs.getDouble('response_flex') ?? 1,
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    _rootController.addListener(_sidebarListener);
    _reqResController.addListener(_reqResListener);
    WidgetsBinding.instance.addObserver(this);
    final hk = HardwareKeyboard.instance;
    hk.addHandler((event) {
      if (event is KeyUpEvent) return false;
      final ctrl = hk.isMetaPressed || hk.isControlPressed;
      if (ctrl && event.logicalKey == LogicalKeyboardKey.keyB) {
        toggleSidebar();
        return true;
      }
      if (ctrl && event.logicalKey == LogicalKeyboardKey.keyJ) {
        _toggleBottomPanel();
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

  void _reqResListener() {
    final reqFlex = _reqResController.areas[0].flex;
    final resFlex = _reqResController.areas[1].flex;
    debouncer.run(() {
      prefs.setDouble('request_flex', reqFlex ?? 1);
      prefs.setDouble('response_flex', resFlex ?? 1);
    });
  }

  void _sidebarListener() {
    final sidebarWidth = _rootController.areas[0].size ?? 0;

    final isDragClose =
        sidebarWidth < (sidebarMinWidth + 2) && isSidebarVisible;

    debouncer.run(() {
      prefs.setDouble('sidebar_width', sidebarWidth);

      if (isDragClose) {
        prefs.remove('last_valid_sidebar_width');
        prefs.setBool('sidebar_closed', true);
      } else {
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
  }

  static double getWindowWidth() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize.width / view.devicePixelRatio;
  }

  void _handleAutoToggleSidebar() {
    windowWidth = getWindowWidth();

    if (windowWidth < sidebarThresholdWidth && isSidebarVisible) {
      isSidebarAutoClosed = true;
      closeSidebar();
      setState(() {});
    } else if (windowWidth >= sidebarThresholdWidth) {
      if (isSidebarAutoClosed) {
        isSidebarAutoClosed = false;
        openSidebar();
        setState(() {});
      }
      scaffoldKey.currentState?.closeDrawer();
    }
  }

  void closeSidebar() {
    setState(() {
      _rootController.areas[0].size = 0;
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
      _rootController.areas[0].size = restoreWidth;
    });
    prefs.setDouble('sidebar_width', restoreWidth);
    prefs.setBool('sidebar_closed', false);
  }

  double getInitialSidebarWidth() {
    if (isSidebarManuallyClosed) {
      return 0;
    }
    double width = prefs.getDouble('sidebar_width') ?? sidebarInitialWidth;

    if (width < 50) {
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
      isSidebarManuallyClosed = true;
      _rootController.areas[0].size = 0;
      prefs.setBool('sidebar_closed', true);
      scaffoldKey.currentState?.closeDrawer();
    } else {
      if (smallWindow) {
        scaffoldKey.currentState?.openDrawer();
      } else {
        openSidebar();
        isSidebarManuallyClosed = false;
      }
    }
    setState(() {});
  }

  void _toggleBottomPanel() {
    ref.read(isBottomPanelVisibleProvider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final isBottomPanelVisible = ref.watch(isBottomPanelVisibleProvider);
    final panelState = ref.watch(panelStateProvider);

    if (!panelState.isMaximized) {
      if (isBottomPanelVisible) {
        if ((_verticalController.areas[1].size ?? 0) < 50) {
          _verticalController.areas[1].size = 300;
        }
      } else {
        _verticalController.areas[1].size = 0;
      }
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: Container(
        color: const Color.fromARGB(255, 32, 29, 32),
        padding: const EdgeInsets.only(top: 30),
        child: SizedBox(width: 300, child: sideBarWidget),
      ),
      body: Column(
        children: [
          TopBar(
            right: [],
            left: [
              IconButton(
                onPressed: toggleSidebar,
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
                controller: _rootController,
                builder: (context, area) {
                  switch (area.data) {
                    case 'side-bar':
                      return sideBarWidget;
                    case 'main-content':
                      if (isBottomPanelVisible && panelState.isMaximized) {
                        return const BottomPanel();
                      }
                      return MultiSplitView(
                        axis: Axis.vertical,
                        controller: _verticalController,
                        builder: (context, vArea) {
                          if (vArea.data == 'content') {
                            return MultiSplitView(
                              controller: _reqResController,
                              builder: (context, rArea) {
                                if (rArea.data == 'request-tab') {
                                  return const ReqTabWrapper();
                                }
                                if (rArea.data == 'response-tab') {
                                  return const ResponseTAb();
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          }
                          if (vArea.data == 'bottom-panel') {
                            return const BottomPanel();
                          }
                          return const SizedBox.shrink();
                        },
                      );

                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
          const StatusBar(),
        ],
      ),
    );
  }
}

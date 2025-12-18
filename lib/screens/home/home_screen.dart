import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/widgets/ui/custom_menu.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:api_craft/screens/home/environment/environment_picker.dart';
import 'package:api_craft/screens/home/request/request.dart';
import 'package:api_craft/screens/home/response/response_tab.dart';
import 'package:api_craft/screens/home/sidebar/sidebar.dart';
import 'package:api_craft/widgets/ui/top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

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
                icon: Icon(
                  isSidebarVisible ? Icons.chevron_left : Icons.chevron_right,
                ),
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

class CollectionPicker extends ConsumerStatefulWidget {
  const CollectionPicker({super.key});

  @override
  ConsumerState<CollectionPicker> createState() => _CollectionPickerState();
}

class _CollectionPickerState extends ConsumerState<CollectionPicker> {
  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();

  @override
  Widget build(BuildContext context) {
    final selectedCollection = ref.watch(selectedCollectionProvider);
    final collections = ref.watch(collectionsProvider).asData?.value ?? [];

    return MyCustomMenu.contentColumn(
      popupKey: _popupKey,
      width: 200,
      items: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "Collections",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        menuDivider,
        ...collections.map((c) {
          final isSelected = c.id == selectedCollection?.id;
          return CustomMenuIconItem.tick(
            title: Text(c.name),
            value: c.id,
            checked: isSelected,
            onTap: (_) {
              ref.read(selectedCollectionProvider.notifier).select(c);
              // change active request
              // ref.read(activeReqIdProvider.notifier).setActiveId(null);
            },
          );
        }),
        menuDivider,
        CustomMenuIconItem(
          icon: const Icon(Icons.add, size: 18),
          title: const Text("Create New..."),
          value: 'create',
          onTap: (_) {
            // Delay to allow popup to close before showing dialog
            Future.microtask(() => _showCreateDialog(context));
          },
        ),

        if (selectedCollection != null) ...[
          menuDivider,
          // menuDivider, // Optional divider before clear history
          CustomMenuIconItem(
            icon: const Icon(Icons.history, size: 18),
            title: const Text("Clear History"),
            value: 'clear_history',
            onTap: (_) {
              ref.read(repositoryProvider).clearHistoryForCollection();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("History cleared")));
            },
          ),
        ],
        if (selectedCollection != null &&
            selectedCollection.id != kDefaultCollection.id)
          CustomMenuIconItem(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            title: const Text(
              "Delete Collection",
              style: TextStyle(color: Colors.red),
            ),
            value: 'delete',
            onTap: (_) {
              Future.microtask(
                () => _showDeleteDialog(context, selectedCollection),
              );
            },
          ),
      ],
      child: TextButton(
        onPressed: () {
          _popupKey.currentState?.show();
        },
        child: Text(
          selectedCollection != null
              ? selectedCollection.name
              : 'Select Collection',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Collection"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Collection Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(collectionsProvider.notifier)
                    .createCollection(name, type: CollectionType.database);
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CollectionModel collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete '${collection.name}'?"),
        content: const Text(
          "This will permanently delete this collection and all its requests, history, and environments.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(collectionsProvider.notifier)
                  .deleteCollection(collection.id);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

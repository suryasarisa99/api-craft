import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/traffic/interceptors/sources/android/adb/adb_client.dart';
import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_android_intercept.dart';
import 'package:api_craft/traffic/utils/icon_cache.dart';
import 'package:flutter/material.dart';

class AndroidPhone extends StatefulWidget {
  final FridaAndroidInterceptor interceptor;
  final double width;
  final String id;

  const AndroidPhone({
    super.key,
    required this.interceptor,
    required this.width,
    required this.id,
  });

  @override
  State<AndroidPhone> createState() => _AndroidPhoneState();
}

class _AndroidPhoneState extends State<AndroidPhone> {
  List<AndroidAppInfo> apps = [];
  List<AndroidAppInfo> filteredApps = [];
  final TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  late final adbDevice = AdbClient.getDevice(widget.id);
  late bool hasProxy = false;
  late bool hasReverseProxy = false;
  int? fridaServerPid;
  bool showSettings = false;
  // late final interceptor = widget.interceptor;
  late final fridaService = widget.interceptor.createFridaService(widget.id);

  @override
  void initState() {
    super.initState();
    adbDevice.hasProxyTo(8000).then((value) {
      setState(() {
        hasProxy = value;
      });
    });
    adbDevice.hasReverseProxyTo(8000).then((value) {
      setState(() {
        hasReverseProxy = value;
      });
    });
    load();
  }

  void load() async {
    final pid = await fridaService.startFridaServer();
    if (pid == null) {
      debugPrint("Frida is not running on device ${widget.id}");
      setState(() {
        isLoading = false;
      });
      return;
    } else {
      setState(() {
        fridaServerPid = pid;
      });
    }
    fridaService.getAppList().then((value) {
      setState(() {
        apps = value;
        filteredApps = apps;
        isLoading = false;
      });
    });
  }

  void launchApp(AndroidAppInfo app) {
    fridaService.launchApp(app.packageName);
  }

  void filterApps() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredApps = apps.where((app) {
        return app.name.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [buildMainScreen(), if (showSettings) buildSettingsScreen()],
    );
  }

  Widget buildMainScreen() {
    return _buildFrame(
      Column(
        children: [
          SizedBox(height: 12),
          _buildSearchBar(),
          if (isLoading)
            Center(child: CircularProgressIndicator())
          else
            Expanded(child: buildAsGrid()),
        ],
      ),
    );
  }

  Widget buildSettingsScreen() {
    return _buildFrame(
      Column(
        children: [
          SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    showSettings = false;
                  });
                },
                icon: Icon(Icons.arrow_back),
              ),
              SizedBox(width: 8),
              Text("Settings"),
            ],
          ),
          // ListTile(
          //   onTap: () {
          //     fridaService.stopFridaServer();
          //   },
          //   title: Text("Kill Frida Server"),
          //   subtitle: FutureBuilder(
          //     future: fridaService.getFridaServerPid(),
          //     builder: (context, snapshot) {
          //       if (snapshot.connectionState == ConnectionState.waiting) {
          //         return Text("Loading...");
          //       }
          //       if (snapshot.hasError) {
          //         return Text("Error: ${snapshot.error}");
          //       }
          //       final pid = snapshot.data;
          //       if (pid == null) {
          //         return Text("Frida server not running");
          //       }
          //       return Text("Frida server PID: $pid");
          //     },
          //   ),
          // ),
          ListTile(
            title: Text("Frida Server"),
            subtitle: Row(
              mainAxisAlignment: .end,
              children: [
                Text(
                  fridaServerPid != null
                      ? "on PID: $fridaServerPid"
                      : "Not Running",
                ),
                Spacer(),

                if (fridaServerPid != null) ...[
                  ElevatedButton(
                    onPressed: () async {
                      await fridaService.stopFridaServer(
                        processId: fridaServerPid,
                      );
                      final pid = await fridaService.startFridaServer();
                      setState(() {
                        fridaServerPid = pid;
                      });
                    },
                    child: Text("Restart"),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await fridaService.stopFridaServer(
                        processId: fridaServerPid,
                      );
                      setState(() {
                        fridaServerPid = null;
                      });
                    },
                    child: Text("Stop"),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: () async {
                      final pid = await fridaService.startFridaServer();
                      setState(() {
                        fridaServerPid = pid;
                      });
                    },
                    child: Text("Start"),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            value: hasReverseProxy,
            title: Text("Reverse Proxy"),
            onChanged: (value) {
              if (value) {
                adbDevice.reverseProxy(8000, 8000);
              } else {
                adbDevice.removeReverseProxy(8000);
              }
              setState(() {
                hasReverseProxy = value;
              });
            },
          ),
          SwitchListTile(
            value: hasProxy,
            title: Text("Proxy"),
            onChanged: (value) {
              if (value) {
                adbDevice.setProxy(8000);
              } else {
                adbDevice.clearProxy();
              }
              setState(() {
                hasProxy = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrame(Widget child) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 22, 22, 22),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [],
          border: Border.all(color: const Color.fromARGB(159, 104, 104, 104)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(child: child),
        ),
      ),
    );
  }

  Widget buildAsList() {
    return ListView.builder(
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        final app = filteredApps[index];
        return ListTile(
          title: Text(app.name),
          subtitle: Text(app.packageName),
          leading: IconCache.imageFromBase64Cached(
            app.iconBase64,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          onTap: () {
            launchApp(app);
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search apps',
                prefixIcon: Padding(
                  padding: const .only(left: 8.0),
                  child: Icon(Icons.search),
                ),
                prefixIconConstraints: BoxConstraints.loose(Size(40, 40)),
                isDense: true,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 187, 159, 149),
                  ),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color.fromARGB(159, 3, 3, 3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (query) {
                filterApps();
                // Implement search logic here
              },
            ),
          ),

          SizedBox(width: 8),
          Switch(
            padding: .zero,
            value: hasProxy,
            onChanged: (value) {
              if (value) {
                adbDevice.setProxy(8000);
              } else {
                adbDevice.clearProxy();
              }
              setState(() {
                hasProxy = value;
              });
            },
          ),
          SizedBox(width: 8),

          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              androidOverlayEntry?.remove();
              androidOverlayEntry = null;
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // show options
              setState(() {
                showSettings = !showSettings;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildAsGrid() {
    return IconsBuilder(
      key: ValueKey(filteredApps.length),
      builder: (context, iconsCount) {
        // final crossAxisCount = (width / appWidth).floor();
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: iconsCount,
            childAspectRatio: 0.8,
          ),
          itemCount: filteredApps.length,
          itemBuilder: (context, index) {
            final app = filteredApps[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                launchApp(app);
              },
              child: Ink(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconCache.imageFromBase64Cached(
                      app.iconBase64,
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 8),
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// we used layoutbuilder,it causes rebuild icons when size changes.
// so we cache the last built widget, only rebuilds when icons count per row changes.
class IconsBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, int iconsCount) builder;

  const IconsBuilder({required this.builder, super.key});

  @override
  State<IconsBuilder> createState() => _IconsBuilderState();
}

class _IconsBuilderState extends State<IconsBuilder> {
  int? _lastIcons;
  late Widget _child;
  static const iconWidth = 70;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final icons = (constraints.maxWidth / iconWidth).floor();
        if (_lastIcons != icons) {
          _lastIcons = icons;
          _child = widget.builder(context, icons);
        }
        return _child;
      },
    );
  }
}

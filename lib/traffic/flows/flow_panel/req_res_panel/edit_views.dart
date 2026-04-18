import 'package:api_craft/api_client/response/widgets/response_body_tab.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/utils/parsers.dart';
import 'package:api_craft/shared/ui/key_value_editor.dart';
import 'package:api_craft/shared/ui/key_value_view.dart';
import 'package:api_craft/api_client/response/widgets/response_cookies_tab.dart';
import 'package:api_craft/traffic/flows/flow_panel/selected_flow_provider.dart';
import 'package:api_craft/traffic/flows/providers/flows_provider.dart';
import 'package:api_craft/traffic/utils/app_icon_service.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class EditHeadersView extends ConsumerStatefulWidget {
  const EditHeadersView({super.key});

  @override
  ConsumerState<EditHeadersView> createState() => _EditHeadersViewState();
}

class _EditHeadersViewState extends ConsumerState<EditHeadersView> {
  @override
  Widget build(BuildContext context) {
    final id = ref.watch(selectedFlowIdProvider);
    final headers = ref.watch(
      flowProvider.select((s) => s?.request?.headers ?? []),
    );

    return KeyValueEditor(
      items: List.from(headers),

      onChanged: (h) {
        final flow = ref.read(flowProvider)!;
        final rq = flow.request!.copyWith(headers: h);
        ref.read(flowsProvider.notifier).editReq(rq);
      },
      id: id,
      mode: .headers,
    );
  }
}

class EditResHeadersView extends ConsumerWidget {
  const EditResHeadersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(selectedFlowIdProvider);
    final headers = ref.watch(
      flowProvider.select((s) => s?.response?.headers ?? []),
    );

    return KeyValueEditor(
      items: List.from(headers),

      onChanged: (h) {
        final flow = ref.read(flowProvider)!;
        final rq = flow.response!.copyWith(headers: h);
        ref.read(flowsProvider.notifier).editRes(rq);
      },
      id: id,
      mode: .headers,
    );
  }
}

class EditQueryParamsView extends ConsumerStatefulWidget {
  const EditQueryParamsView({super.key});

  @override
  ConsumerState<EditQueryParamsView> createState() =>
      _EditQueryParamsViewState();
}

class _EditQueryParamsViewState extends ConsumerState<EditQueryParamsView> {
  // We keep a local cache of items to preserve their IDs across builds
  // (because parsing from URL generates new IDs every time)
  List<KeyValueItem> _items = [];
  String? _lastUrl;

  @override
  void initState() {
    super.initState();
  }

  void _mergeItems(List<List<String>> newParams, String currentUrl) {
    if (_lastUrl == currentUrl) return;
    _lastUrl = currentUrl;

    final newItems = <KeyValueItem>[];
    final availableOldItems = List<KeyValueItem>.from(_items);

    for (final param in newParams) {
      final key = param[0];
      final value = param[1];

      // Try to find an existing item that matches key/value to preserve ID
      final matchIndex = availableOldItems.indexWhere(
        (item) => item.key == key && item.value == value,
      );

      if (matchIndex != -1) {
        newItems.add(availableOldItems[matchIndex]);
        availableOldItems.removeAt(matchIndex);
      } else {
        // Fallback: try to find one with just matching key (maybe value changed externally? unlikely but okay)
        // actually for query params, if order changes or duplicates exist, it's tricky.
        // For now, strict match or new ID is safer for stability vs "guessing" if it's the same item modified.
        // But since we are only syncing FROM url here, strict match is good.
        // If we modify in UI, we update _items directly so ID is preserved.
        newItems.add(KeyValueItem(key: key, value: value));
      }
    }

    _items = newItems;
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(selectedFlowIdProvider);
    final flow = ref.watch(flowProvider);
    final queryParams = ref.watch(queryParamsProvider);

    // Sync from provider if needed
    if (flow?.request?.url != null) {
      _mergeItems(queryParams, flow!.request!.url);
    }

    return KeyValueEditor(
      items: List.from(_items),
      onChanged: (h) {
        // 1. Update local state immediately
        setState(() {
          _items = h;
        });

        // 2. Update the flow (this will eventually trigger a rebuild with new URL)
        final flow = ref.read(flowProvider)!;
        final newUrl = ParserUtils.buildUrl(flow.request!.url, h);

        // Update _lastUrl to prevent immediate overwrite when the provider updates
        // This is a bit optimistic but helps prevent jitter
        _lastUrl = newUrl;

        final rq = flow.request!.copyWith(url: newUrl);
        ref.read(flowsProvider.notifier).editReq(rq);
      },
      id: id,
      mode: KeyValueEditorMode.queryParams,
    );
  }
}

class EditCookiesView extends ConsumerStatefulWidget {
  const EditCookiesView({super.key});

  @override
  ConsumerState<EditCookiesView> createState() => _EditCookiesViewState();
}

class _EditCookiesViewState extends ConsumerState<EditCookiesView> {
  List<List<KeyValueItem>> _cookies = [];
  @override
  void initState() {
    super.initState();
    final headers = ref.read(
      flowProvider.select((s) => s?.request?.headers ?? []),
    );
    final cookiesList = ParserUtils.parseMultipleCookies(headers);
    _cookies = [
      for (final cookie in cookiesList)
        [for (final item in cookie) KeyValueItem(key: item[0], value: item[1])],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, cookie) in _cookies.indexed)
          Expanded(
            child: KeyValueEditor(
              items: cookie,
              onChanged: (h) {
                setState(() {
                  _cookies[i] = h;
                });
              },
              id: ref.watch(selectedFlowIdProvider),
              mode: .queryParams,
            ),
          ),
      ],
    );
  }
}

class ReadOnlyCookiesView extends ConsumerStatefulWidget {
  const ReadOnlyCookiesView({super.key});

  @override
  ConsumerState<ReadOnlyCookiesView> createState() =>
      _ReadOnlyCookiesViewState();
}

class _ReadOnlyCookiesViewState extends ConsumerState<ReadOnlyCookiesView> {
  List<List<String>> _cookies = [];
  @override
  void initState() {
    super.initState();
    final headers = ref.read(
      flowProvider.select((s) => s?.request?.headers ?? []),
    );
    final cookiesList = ParserUtils.parseMultipleCookies(headers);
    _cookies = cookiesList.expand((x) => x).toList();
  }

  @override
  Widget build(BuildContext context) {
    final headerClr = Theme.of(context).colorScheme.primary;
    return KeyValueView(
      items: _cookies,
      pairSeparator: "=",
      itemSeparator: "; ",
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      keyStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        // color: Color(0xFFD34399),
        color: headerClr,
      ),
      valueStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

class ReadOnlySetCookiesView extends ConsumerStatefulWidget {
  const ReadOnlySetCookiesView({super.key});

  @override
  ConsumerState<ReadOnlySetCookiesView> createState() =>
      _ReadOnlySetCookiesViewState();
}

class _ReadOnlySetCookiesViewState
    extends ConsumerState<ReadOnlySetCookiesView> {
  List<CookieDef> _cookies = [];
  @override
  void initState() {
    super.initState();
    final headers = ref.read(
      flowProvider.select((s) => s?.response?.headers ?? []),
    );
    _cookies = HeaderUtils.getSetCookies(headers, null);
  }

  @override
  Widget build(BuildContext context) {
    return SetCookiesView(cookies: _cookies);
  }
}

class ReadOnlyBodyView extends ConsumerWidget {
  const ReadOnlyBodyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(flowProvider.select((s) => s?.response?.body));
    if (body == null) {
      return const SizedBox.shrink();
    }
    final contentType = ref.watch(
      flowProvider.select(
        (s) => s?.response?.headers?.firstWhereOrNull(
          (k) => k.key.toLowerCase() == "content-type",
        ),
      ),
    );
    final id = ref.watch(flowProvider.select((s) => s?.id));
    return ResponseBodyView(
      body: body,
      contentType: contentType?.value,
      mode: .pretty,
      id: id!,
    );
  }
}

class ClientInfoView extends ConsumerWidget {
  const ClientInfoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientInfo = ref.watch(
      flowProvider.select((s) => s?.request?.clientInfo),
    );
    if (clientInfo == null) {
      return const SizedBox.shrink();
    }

    final processPath = clientInfo.processPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (processPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _AppDetails(path: processPath, pid: clientInfo.pid),
          )
        else
          const Text(
            "Client Info",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        SelectableText.rich(
          TextSpan(
            style: const TextStyle(height: 1.5),
            children: [
              TextSpan(text: "IP: ${clientInfo.ipAddress}\n"),
              TextSpan(text: "Port: ${clientInfo.port}\n"),
              TextSpan(text: 'name: ${clientInfo.appName}\n'),
              if (processPath == null) ...[
                TextSpan(text: "App Name: ${clientInfo.appName}\n"),
                TextSpan(text: "App Version: ${clientInfo.appVersion}\n"),
              ],
              TextSpan(text: "Platform: ${clientInfo.platform}\n"),
              TextSpan(text: "OS Version: ${clientInfo.osVersion}\n"),
              TextSpan(text: "Device Name: ${clientInfo.deviceName}"),
            ],
          ),
        ),
      ],
    );
  }

  Future<({int? pid, String? processPath})?> _resolveProcessInfo(
    int port,
    String? ip,
  ) async {
    if (ip != '127.0.0.1' && ip != '::1') return null;
    if (!Platform.isMacOS) return null;

    try {
      final result = await Process.run('lsof', ['-i', ':$port', '-F', 'p']);
      final output = result.stdout as String;
      if (output.isEmpty) return null;

      final lines = output.split('\n');
      int? clientPid;
      final currentPid = pid; // Capture global pid

      for (final line in lines) {
        if (line.startsWith('p')) {
          final parsedPid = int.tryParse(line.substring(1));
          if (parsedPid != null && parsedPid != currentPid) {
            clientPid = parsedPid;
            break;
          }
        }
      }

      if (clientPid != null) {
        final psResult = await Process.run('ps', [
          '-p',
          '$clientPid',
          '-o',
          'comm=',
        ]);
        final path = (psResult.stdout as String).trim();
        if (path.isNotEmpty) {
          return (pid: clientPid, processPath: path);
        }
      }
    } catch (e) {
      debugPrint("Error resolving process: $e");
    }
    return null;
  }
}

class _AppDetails extends StatefulWidget {
  final String path;
  final int? pid;
  const _AppDetails({required this.path, this.pid});

  @override
  State<_AppDetails> createState() => _AppDetailsState();
}

class _AppDetailsState extends State<_AppDetails> {
  Uint8List? _iconBytes;
  String _appName = "";

  @override
  void initState() {
    super.initState();
    _appName = p.basename(widget.path);

    _loadDetails();
  }

  Future<void> _loadDetails() async {
    String? appBundlePath;
    final index = widget.path.lastIndexOf('.app/');
    if (index != -1) {
      appBundlePath = widget.path.substring(0, index + 4);
    } else if (widget.path.endsWith('.app')) {
      appBundlePath = widget.path;
    }
    print("appBundlePath: $appBundlePath");
    if (appBundlePath != null) {
      if (mounted) {
        setState(() {
          _appName = p.basenameWithoutExtension(appBundlePath!);
        });
      }

      final bytes = await AppIconService.getAppIcon(widget.path);
      if (mounted && bytes != null) {
        setState(() {
          _iconBytes = bytes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (_iconBytes != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Image.memory(_iconBytes!, width: 32, height: 32),
          )
        else
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Icons.apps, size: 32),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.pid != null)
              Text(
                "PID: ${widget.pid}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }
}

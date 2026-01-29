import 'package:api_craft/core/services/system_proxy.dart';
import 'package:api_craft/shared/ui/surya_theme_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suryaicons/bulk_rounded.dart';

class SystemProxyWidget extends ConsumerStatefulWidget {
  const SystemProxyWidget({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SystemProxyWidgetState();
}

class _SystemProxyWidgetState extends ConsumerState<SystemProxyWidget> {
  var systemProxy = false;

  @override
  void initState() {
    super.initState();
    _checkProxyStatus();
  }

  Future<void> _checkProxyStatus() async {
    final enabled = await SystemProxy.isProxyEnabled();
    debugPrint("system proxy enabled: $enabled");
    setState(() {
      systemProxy = enabled;
    });
  }

  Future<void> _toggleProxy() async {
    Future<Map<String, dynamic>> future;

    if (systemProxy) {
      future = SystemProxy.clearProxy();
    } else {
      future = SystemProxy.setProxy(host: "127.0.0.1", port: 8000);
    }
    // toggle immediately,because it few seconds to update proxy and get status.
    setState(() {
      systemProxy = !systemProxy;
    });
    final result = await future;
    final isSuccess = result['success'] == true;
    if (!isSuccess) {
      // revert state
      setState(() {
        systemProxy = !systemProxy;
      });
    }
    debugPrint("set proxy result: $result");
    // _checkProxyStatus();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SuryaThemeIcon(systemProxy ? BulkRounded.pause : BulkRounded.play),
      tooltip: systemProxy ? 'Disable System Proxy' : 'Enable System Proxy',
      onPressed: _toggleProxy,
    );
  }
}

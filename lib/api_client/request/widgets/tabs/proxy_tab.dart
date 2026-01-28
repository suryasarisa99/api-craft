import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/api_client/request/models/node_config_model.dart';
import 'package:api_craft/api_client/request/models/node_model.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyTab extends ConsumerStatefulWidget {
  final String id;
  const ProxyTab({super.key, required this.id});

  @override
  ConsumerState<ProxyTab> createState() => _ProxyTabState();
}

class _ProxyTabState extends ConsumerState<ProxyTab> {
  final debouncer = Debouncer(Duration(milliseconds: 500));

  @override
  Widget build(BuildContext context) {
    final proxy = ref.watch(
      reqComposeProvider(widget.id).select(
        (v) =>
            (v.node as FolderNode).folderConfig.proxy ?? const ProxySettings(),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Using System Proxy",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Spacer(),
              Switch(
                value: proxy.isEnabled,
                onChanged: (val) {
                  _updateProxy(proxy.copyWith(isEnabled: val));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (proxy.isEnabled) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: proxy.protocol,
                    decoration: const InputDecoration(
                      labelText: "Protocol",
                      hintText: "http",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _updateProxy(
                      proxy.copyWith(protocol: val),
                      debounce: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    initialValue: proxy.host ?? '',
                    decoration: const InputDecoration(
                      labelText: "Host",
                      hintText: "127.0.0.1",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _updateProxy(proxy.copyWith(host: val), debounce: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: proxy.port ?? '',
                    decoration: const InputDecoration(
                      labelText: "Port",
                      hintText: "8080",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _updateProxy(proxy.copyWith(port: val), debounce: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Authentication (Optional)"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: proxy.username ?? '',
                    decoration: const InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _updateProxy(
                      proxy.copyWith(username: val),
                      debounce: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: proxy.password ?? '',
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _updateProxy(
                      proxy.copyWith(password: val),
                      debounce: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _updateProxy(ProxySettings newSettings, {bool debounce = false}) {
    if (debounce) {
      debouncer.run(() {
        _performUpdate(newSettings);
      });
    } else {
      _performUpdate(newSettings);
    }
  }

  void _performUpdate(ProxySettings newSettings) {
    ref
        .read(reqComposeProvider(widget.id).notifier)
        .updateProxySettings(newSettings);
  }
}

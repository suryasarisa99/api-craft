import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

const fridaScriptsRoot = 'assets/scripts/frida';

String buildFridaConfig(
  String configScriptTemplate,
  String caCertContent,
  String proxyHost,
  int proxyPort,
  List<int> portsToIgnore,
  bool enableSocks,
) {
  return configScriptTemplate
      .replaceAllMapped(
        RegExp(r'(?<=const CERT_PEM = `)[^`]+(?=`)', dotAll: true),
        (_) => caCertContent.trim(),
      )
      .replaceAllMapped(
        RegExp(r"(?<=const PROXY_HOST = ')[^']+(?=')"),
        (_) => proxyHost,
      )
      .replaceAllMapped(
        RegExp(r'(?<=const PROXY_PORT = )\d+(?=;)'),
        (_) => proxyPort.toString(),
      )
      .replaceAllMapped(
        RegExp(r'(?<=const PROXY_SUPPORTS_SOCKS5 = )false(?=;)'),
        (_) => enableSocks.toString(),
      )
      .replaceAllMapped(
        RegExp(
          r'(?<=const IGNORED_NON_HTTP_PORTS = )$begin:math:display$\\s\*$end:math:display$(?=;)',
          dotAll: true,
        ),
        (_) => portsToIgnore.toString(), // Dart prints list as [80,443]
      );
}

Future<String> buildAndroidFridaScript(
  String caCertContent,
  String proxyHost,
  int proxyPort,
  List<int> portsToIgnore,
  bool enableSocks,
) async {
  final x = await rootBundle
      .loadString(p.join(fridaScriptsRoot, 'config.js'))
      .then((configTemplate) {
        return buildFridaConfig(
          configTemplate,
          caCertContent,
          proxyHost,
          proxyPort,
          portsToIgnore,
          enableSocks,
        );
      });
  // log("script lines: ${x.split('\n').length}");
  final scriptsFuture = [
    // rootBundle.loadString(p.join(fridaScriptsRoot, 'frida-java-bridge.js')),
    rootBundle.loadString(p.join(fridaScriptsRoot, 'config.js')).then((
      configTemplate,
    ) {
      return buildFridaConfig(
        configTemplate,
        caCertContent,
        proxyHost,
        proxyPort,
        portsToIgnore,
        enableSocks,
      );
    }),
    ...[
      /* native-connect-hook: to make apps to use proxy,for apps like flutter apps do not use standard APIs*/
      ['native-connect-hook.js'],
      ['native-tls-hook.js'],
      /*android-proxy-override: to work with reverse proxy*/
      ['android', 'android-proxy-override.js'],
      ['android', 'android-system-certificate-injection.js'],
      ['android', 'android-certificate-unpinning.js'],
      ['android', 'android-certificate-unpinning-fallback.js'],
      // ['android', 'root-and-emulator-bypass.js'],
      ['android', 'android-disable-root-detection.js'],
    ].map((path) {
      return rootBundle.loadString(p.joinAll([fridaScriptsRoot, ...path]));
    }),
  ];
  final scripts = await Future.wait(scriptsFuture);
  final script = scripts.join('\n\n');
  return script;
}

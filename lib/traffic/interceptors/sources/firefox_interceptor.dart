import 'dart:io';
import 'package:api_craft/traffic/interceptors/utils/browser_utils.dart';
import 'package:api_craft/traffic/interceptors/models/interceptor_model.dart';
import 'package:api_craft/traffic/interceptors/utils/cmd_utils.dart';
import 'package:api_craft/traffic/interceptors/utils/get_certificate.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

class FirefoxInterceptor extends Interceptor {
  @override
  get name => "Firefox Interceptor";
  @override
  get description => "Launches Firefox-based browsers with proxy settings.";
  @override
  get tags => ["firefox", "browser"];

  @override
  getOptions() async {
    return BrowserUtils.firefoxBasedBrowsers;
  }

  @override
  getSubOptions(dynamic option) {
    return null;
  }

  @override
  launch(LaunchConfig config) {
    if (config.option == null) {
      debugPrint("option :name is required to launch firefox based browsers");
      return;
    }
    final caCertPath = getCertificatePath();
    FirefoxProxy.launch(
      proxyPort: config.proxyPort,
      proxyHost: config.proxyHost,
      caCertPath: caCertPath,
      name: config.option,
    );
  }
}

class FirefoxProxy {
  /// Checks if 'certutil' is installed (Required for Firefox cert injection)
  static Future<String?> findCertutil() async {
    final searchPaths = [
      '/opt/homebrew/bin/certutil', // Apple Silicon
      '/usr/local/opt/nss/bin/certutil', // Intel Mac
      '/usr/bin/certutil',
    ];

    for (var path in searchPaths) {
      if (await File(path).exists()) return path;
    }

    // Check global path
    try {
      final result = await Process.run('which', ['certutil']);
      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}

    return null;
  }

  static Future<void> launch({
    String proxyPort = "8000",
    String proxyHost = "127.0.0.1",
    required String caCertPath,
    String name = "Firefox", // to work with other firefox based browsers
  }) async {
    if (!Platform.isMacOS) return;

    // 1. Create a unique temporary profile directory
    final tempDir = await Directory.systemTemp.createTemp('dart_firefox_mitm_');
    final profilePath = tempDir.path;
    debugPrint("Firefox Profile: $profilePath");

    // 2. Write the comprehensive 'user.js' (prefs.js)
    // This matches the Proxyman configuration for stability and silence.
    final userJsContent =
        '''
// Proxy Configuration
user_pref("network.proxy.type", 1);
user_pref("network.proxy.http", "$proxyHost");
user_pref("network.proxy.http_port", $proxyPort);
user_pref("network.proxy.ssl", "$proxyHost");
user_pref("network.proxy.ssl_port", $proxyPort);
user_pref("network.proxy.no_proxies_on", "localhost,$proxyHost");

// Security & Trust (Allow the MITM to work smoothly)
user_pref("security.enterprise_roots.enabled", true);
user_pref("dom.security.https_only_mode", false); 
user_pref("security.mixed_content.block_active_content", false);
user_pref("security.mixed_content.block_display_content", false);
user_pref("security.cert_pinning.enforcement_level", 0);
user_pref("security.OCSP.enabled", 0);

// Disable UI Popups at Startup
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.welcome.enabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("extensions.update.enabled", false);
user_pref("app.update.auto", false);
user_pref("extensions.autoDisableScopes", 0);
''';

    await File(p.join(profilePath, 'user.js')).writeAsString(userJsContent);

    // 3. Inject Certificate using certutil
    final certUtilPath = await findCertutil();

    if (certUtilPath == null) {
      debugPrint(
        "⚠️ WARNING: 'certutil' not found. HTTPS traffic will show security warnings.",
      );
      debugPrint("👉 Run: 'brew install nss' to fix this.");
    } else {
      debugPrint("Found certutil at: $certUtilPath. Injecting certificate...");

      final certArgs = [
        '-A', // Add
        '-n', 'Dart MITM Custom Cert', // Nickname
        '-t', 'C,,', // Trust flags (C=Trusted for SSL)
        '-i', caCertPath, // Input file
        '-d',
        'sql:$profilePath', // Target DB (sql: prefix is mandatory for modern Firefox)
      ];

      final certResult = await Process.run(certUtilPath, certArgs);

      if (certResult.exitCode != 0) {
        debugPrint("Failed to inject cert: ${certResult.stderr}");
      } else {
        debugPrint("Certificate injected successfully.");
      }
    }

    // 4. Launch Firefox
    final firefoxCmd = [
      'open',
      '-n', // New Instance
      '-F', // Fresh (no state restoration)
      '-a', '"$name"',
      '--args',
      '-profile', profilePath,
    ];
    runCmd(firefoxCmd.join(' '));
  }
}

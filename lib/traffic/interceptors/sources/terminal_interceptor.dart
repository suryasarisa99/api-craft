import 'dart:io';
import 'package:api_craft/traffic/interceptors/models/interceptor_model.dart';
import 'package:api_craft/traffic/interceptors/utils/cmd_utils.dart';
import 'package:api_craft/traffic/interceptors/utils/get_certificate.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

class TerminalProxyInterceptor extends Interceptor {
  @override
  get name => "Terminal Proxy Interceptor";
  @override
  get description =>
      "Launches a terminal application with environment variables set to route traffic through the proxy.";
  @override
  get tags => ["terminal", "environment"];

  @override
  getOptions() async {
    // return TerminalProxy.detectInstalledTerminals();
    final terminals = TerminalProxy.commonTerminals.keys.toList();
    debugPrint("Detected terminals: $terminals");
    return terminals;
  }

  @override
  getSubOptions(dynamic option) {
    return null;
  }

  @override
  launch(LaunchConfig config) {
    if (config.option == null) {
      debugPrint("No terminal application selected for proxying.");
      return;
    }
    final terminalAppPath = config.option as String;
    final caCertPath = getCertificatePath();
    TerminalProxy.launchProxiedTerminal(
      proxyPort: config.proxyPort,
      proxyHost: config.proxyHost,
      caCertPath: caCertPath,
      terminalAppPath: terminalAppPath,
    );
  }
}

class TerminalProxy {
  // List of common terminal applications and their bundle identifiers/paths
  static const Map<String, String> commonTerminals = {
    'Terminal': '/System/Applications/Utilities/Terminal.app',
    'iTerm': '/Applications/iTerm.app',
  };

  static Future<void> launchProxiedTerminal({
    required String proxyPort,
    required String proxyHost,
    required String caCertPath,
    required String terminalAppPath,
  }) async {
    if (!Platform.isMacOS) {
      debugPrint("Terminal proxying is only implemented for macOS.");
      return;
    }

    final homeDir = getHomeDirectory();
    final tempDir = Directory(p.join(homeDir, '.mitmproxy_dart'));
    await tempDir.create(recursive: true);

    final proxyHostPort = "$proxyHost:$proxyPort";
    final scriptContent = genTerminalScript(caCertPath, proxyHostPort);

    final scriptPath = p.join(tempDir.path, 'dart_proxy_session.command');

    await File(scriptPath).writeAsString(scriptContent);

    // Make it executable
    await Process.run('chmod', ['+x', scriptPath]);

    debugPrint("Launching $terminalAppPath with script $scriptPath");

    final result = await Process.run('open', [
      '-a',
      terminalAppPath,
      scriptPath,
    ]);

    if (result.exitCode != 0) {
      debugPrint("Error launching terminal: ${result.stderr}");
    } else {
      debugPrint("Launched ${p.basename(terminalAppPath)} successfully.");
    }
  }

  /*
  - DEPRECATED METHOD: Uses AppleScript to directly tell the terminal to run the script.
  */
  static Future<void> launchProxiedTerminalOldWay({
    required String proxyPort,
    required String proxyHost,
    required String caCertPath,
    required String terminalAppPath,
  }) async {
    if (!Platform.isMacOS) {
      debugPrint("Terminal proxying is only implemented for macOS.");
      return;
    }

    final homeDir = getHomeDirectory();
    final tempDir = Directory(p.join(homeDir, '.mitmproxy_dart'));
    await tempDir.create(recursive: true);
    final proxyHostPort = "$proxyHost:$proxyPort";
    final scriptContent = genTerminalScript(caCertPath, proxyHostPort);
    final scriptPath = p.join(tempDir.path, 'dart_proxy_session.sh');
    await File(scriptPath).writeAsString(scriptContent);
    await Process.run('chmod', ['+x', scriptPath]);

    String appleScript;
    final appName = p.basenameWithoutExtension(terminalAppPath);
    if (terminalAppPath.toLowerCase().contains('iterm')) {
      // iTerm2 specific AppleScript syntax
      appleScript =
          '''
      tell application "$appName"
        activate
        try
          set newWindow to (create window with default profile)
          tell current session of newWindow
            write text "source \\"$scriptPath\\""
          end tell
        on error
          display dialog "Failed to interact with iTerm. Make sure to grant Automation permissions."
        end try
      end tell
    ''';
    } else {
      // Default Apple Terminal specific AppleScript syntax
      appleScript =
          '''
      tell application "$appName"
        activate
        do script "source \\"$scriptPath\\""
      end tell
    ''';
    }
    debugPrint('osascript -e $appleScript');
    await Process.run('osascript', ['-e', appleScript]);
    debugPrint(
      "Launched ${p.basename(terminalAppPath)} with proxy environment sourced.",
    );
  }

  static Future<List<String>> detectInstalledTerminals() async {
    final installed = <String>[];

    // Check known paths directly
    for (var entry in commonTerminals.entries) {
      if (await Directory(entry.value).exists()) {
        installed.add(entry.key);
      }
    }

    // Fallback: Use system_profiler (more comprehensive but slower)
    if (installed.isEmpty) {
      // NOTE: This is slow. Checking known paths is much faster and usually sufficient.
      final result = await Process.run('system_profiler', [
        'SPApplicationsDataType',
      ]);
      if (result.exitCode == 0) {
        if (result.stdout.toString().contains('iTerm')) {
          installed.add('iTerm');
        }
        if (result.stdout.toString().contains('Terminal')) {
          installed.add('Terminal');
        }
      }
    }

    return installed;
  }
}

const String _noProxyList = "localhost,127.0.0.1,:: 1,*.local,*.localhost";
String genTerminalScript(String caCertPath, String proxyHostPort) {
  // This replicates the comprehensive setup from Proxyman
  return '''
#!/bin/bash

# --- STANDARD HTTP/HTTPS PROXY ---
export HTTP_PROXY="$proxyHostPort"
export HTTPS_PROXY="$proxyHostPort"
export http_proxy="$proxyHostPort"
export https_proxy="$proxyHostPort"
export CGI_HTTP_PROXY="$proxyHostPort"
export ALL_PROXY="$proxyHostPort"

# --- NO PROXY CONFIGURATION ---
export NO_PROXY="$_noProxyList"
export no_proxy="$_noProxyList"

# --- CERTIFICATE AUTHORITY PATHS (Universal) ---
export CA_BUNDLE="$caCertPath"
export CARGO_HTTP_CAINFO="$caCertPath"        # Rust/Cargo
export CURL_CA_BUNDLE="$caCertPath"           # Curl
export GIT_SSL_CAINFO="$caCertPath"           # Git
export NODE_EXTRA_CA_CERTS="$caCertPath"      # Node.js
export PERL_LWP_SSL_CA_FILE="$caCertPath"     # Perl
export REQUESTS_CA_BUNDLE="$caCertPath"       # Python Requests
export SSL_CERT_FILE="$caCertPath"            # OpenSSL Generic
export SSL_CERT_DIR="\$(dirname "$caCertPath")" # OpenSSL Directory

# --- LANGUAGE SPECIFIC CONFIGURATIONS ---

# Node.js / NPM
export npm_config_proxy="$proxyHostPort"
export npm_config_https_proxy="$proxyHostPort"
export npm_config_no_proxy="$_noProxyList"
export NODE_TLS_REJECT_UNAUTHORIZED="0"       # Disable strict SSL (optional but recommended for MITM)
export GLOBAL_AGENT_HTTP_PROXY="$proxyHostPort"
export GLOBAL_AGENT_NO_PROXY="$_noProxyList"

# Go Lang
# GODEBUG: x509ignoreCN=0 allows legacy Common Name matching
# http2server=0 disables HTTP/2 server support which helps with some MITM parsing
export GODEBUG="x509ignoreCN=0,http2server=0" 
export GOFLAGS="-insecure"
export GOPROXY="$proxyHostPort,direct"        # Route Go module downloads through proxy

# Ruby / Fastlane
export SPACESHIP_PROXY="$proxyHostPort"
export SPACESHIP_PROXY_SSL_VERIFY_NONE=1

# Java / Gradle (Common environment variables)
export JAVA_OPTS="-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9091 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9091 -Dhttp.nonProxyHosts='$_noProxyList'"
export GRADLE_OPTS="-DsystemProp.http.proxyHost=127.0.0.1 -DsystemProp.http.proxyPort=9091 -DsystemProp.https.proxyHost=127.0.0.1 -DsystemProp.https.proxyPort=9091"

# --- GENERIC INSECURE FLAGS ---
export SSL_VERIFY_NONE=true

# --- SHELL FEEDBACK ---
clear
echo "----------------------------------------------"
echo "------ DART MITM PROXY TERMINAL SETUP --------"
echo "----------------------------------------------"
echo "✅ Active Proxy: $proxyHostPort"
echo "Capturing HTTP/HTTPS traffic from this terminal session"
echo "Support NodeJS: (axios, fetch, got, request, superagent)"
echo "Support Ruby: (http, net/http, net/https)"
echo "Support Python: (http, httplib, httplib2)"
echo "Support Golang: (net/http, fasthttp, resty, gorequest, req, grequests)"
echo ""
echo "⚠️  This session is fully proxied and intercepts HTTPS traffic."
echo "👉 To stop, close this terminal or run 'unset HTTP_PROXY HTTPS_PROXY ALL_PROXY'"
echo "----------------------------------------------"

# CRITICAL FOR .command EXECUTION:
# This replaces the script process with a new interactive shell.
# This keeps the window open and preserves the environment variables.
exec "\${SHELL:-/bin/bash}"
''';
}

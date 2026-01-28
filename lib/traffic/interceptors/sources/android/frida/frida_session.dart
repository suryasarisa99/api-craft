import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_android_intercept.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FridaSession {
  Process? _sessionProcess;
  Process? _process;
  final String envPath;
  final String deviceId;
  FridaSession({required this.envPath, required this.deviceId});
  final StreamController<String> _streamController = StreamController<String>();

  /// Starts the Frida interception session.
  ///
  /// [envPath]: Path to the Python environment folder.
  /// [deviceId]: 'usb', 'remote', or a specific device ID.
  /// [packageId]: The Android/iOS package name (e.g., com.example.app).
  /// [jsHookCode]: The actual Frida JavaScript code to inject.
  /// [onMessage]: Callback when the JS sends `send(...)`.
  /// [onError]: Callback for generic errors.
  /// [onStatus]: Callback for status updates (e.g., "Attached", "Detached").

  Future<Stream<String>> startSession({
    required String packageId,
    required String script,
    required Function(dynamic payload) onMessage,
    required Function(String error) onError,
    required Function(String status) onStatus,
  }) async {
    try {
      // 1. Resolve Python Path
      final pythonPath = PythonEnv.getExePath(envPath);

      // 2. Prepare the Adapter Script
      final adapterPath = await _createAdapterScript();

      debugPrint("🚀 Launching Frida Adapter...");
      debugPrint("   Python: $pythonPath");
      debugPrint("   Target: $packageId");

      // 3. Start the Process
      _sessionProcess = await Process.start(
        pythonPath,
        [
          adapterPath,
          '--device',
          deviceId,
          '--package',
          packageId,
          '--script',
          script,
        ],
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      // 4. Listen to STDOUT (Data Stream)
      _sessionProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _handleOutput(line, onMessage, onError, onStatus);
          });

      // 5. Listen to STDERR (System Errors)
      _sessionProcess!.stderr.transform(utf8.decoder).listen((error) {
        // Python tracebacks or import errors show up here
        if (error.trim().isNotEmpty) {
          debugPrint("🚨 STDERR: $error");
          onError("System Error: $error");
        }
      });

      // 6. Handle Process Exit
      _sessionProcess!.exitCode.then((code) {
        onStatus("Session ended (Exit code: $code)");
        _sessionProcess = null;
      });
    } catch (e) {
      onError("Failed to start session: $e");
    }
    return _streamController.stream;
  }

  Future<List<AndroidAppInfo>> getAppListNoIcons({
    required String deviceId,
    required Function(String error) onError,
  }) async {
    final completer = Completer<List<AndroidAppInfo>>();
    final List<AndroidAppInfo> apps = [];

    try {
      final pythonPath = PythonEnv.getExePath(envPath);
      final adapterPath = await _createAdapterScript();

      debugPrint("🚀 Fetching App List...");

      _process = await Process.start(pythonPath, [
        adapterPath,
        '--action',
        'list_apps_no_icons',
        '--device',
        deviceId,
      ], runInShell: false);

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            final cleanLine = line.trim();
            if (!cleanLine.startsWith("DART_DATA:")) return;

            try {
              final jsonStr = cleanLine.substring("DART_DATA:".length);
              final data = jsonDecode(jsonStr);

              if (data['type'] == 'app_list') {
                for (var appData in data['payload']) {
                  apps.add(
                    AndroidAppInfo(
                      name: appData['name'] ?? "Unknown",
                      packageName: appData['id'] ?? "unknown.pkg",
                      iconBase64: "",
                    ),
                  );
                }
              }

              if (data['type'] == 'end') {
                if (!completer.isCompleted) {
                  completer.complete(apps);
                }
              }

              if (data['type'] == 'fatal') {
                if (!completer.isCompleted) {
                  completer.completeError(data['msg']);
                }
                onError(data['msg']);
              }
            } catch (e) {
              debugPrint("Parse Error: $e");
            }
          });

      _process!.exitCode.then((_) {
        if (!completer.isCompleted) {
          completer.complete(apps); // fallback
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError("Failed to list apps: $e");
      }
      onError("Failed to list apps: $e");
    }

    return completer.future;
  }

  Future<List<AndroidAppInfo>> getAppList() async {
    final completer = Completer<List<AndroidAppInfo>>();
    final List<AndroidAppInfo> apps = [];
    int expectedCount = -1;

    try {
      final pythonPath = PythonEnv.getExePath(envPath);
      final adapterPath = await _createAdapterScript();

      debugPrint("🚀 Fetching App List...");

      _process = await Process.start(pythonPath, [
        adapterPath,
        '--action',
        'list_apps',
        '--device',
        deviceId,
      ], runInShell: false);

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            final cleanLine = line.trim();
            if (!cleanLine.startsWith("DART_DATA:")) return;

            try {
              final jsonStr = cleanLine.substring("DART_DATA:".length);
              final data = jsonDecode(jsonStr);

              // total app count
              if (data['type'] == 'apps_count') {
                expectedCount = data['payload'];
              }

              // app item
              if (data['type'] == 'app_list_item') {
                final p = data['payload'];

                apps.add(
                  AndroidAppInfo(
                    name: p['name'] ?? "Unknown",
                    packageName: p['id'] ?? "unknown.pkg",
                    iconBase64: p['icon'] ?? "",
                  ),
                );

                // All apps received
                if (expectedCount > 0 && apps.length == expectedCount) {
                  if (!completer.isCompleted) {
                    completer.complete(apps);
                  }
                }
              }

              // fatal error from python
              if (data['type'] == 'fatal') {
                if (!completer.isCompleted) {
                  completer.completeError(data['msg']);
                }
              }
            } catch (_) {}
          });

      // if process exits but not completed
      _process!.exitCode.then((_) {
        if (!completer.isCompleted) {
          completer.complete(apps);
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError("Failed to list apps: $e");
      }
    }

    return completer.future;
  }

  /// Parses lines from the Python script
  void _handleOutput(
    String line,
    Function(dynamic) onMessage,
    Function(String) onError,
    Function(String) onStatus,
  ) {
    final cleanLine = line.trim();

    // We only care about our custom protocol
    if (!cleanLine.startsWith("DART_DATA:")) return;

    try {
      final jsonStr = cleanLine.substring("DART_DATA:".length);
      final data = jsonDecode(jsonStr);
      final type = data['type'];

      switch (type) {
        case 'message':
          // This corresponds to send(...) in JS
          onMessage(data['payload']);
          _streamController.add(data['payload']);
          break;
        case 'error':
          // This corresponds to a JS crash/exception
          onError("JS Error: ${data['description']}\nStack: ${data['stack']}");
          break;
        case 'status':
          onStatus(data['msg']);
          break;
        case 'fatal':
          onError("Frida Error: ${data['msg']}");
          break;
        case 'detached':
          onStatus("Target App Detached: ${data['reason']}");
          stop(); // Kill the python process since the app is gone
          break;
      }
    } catch (e) {
      debugPrint("⚠️ JSON Parse Error: $e\nLine: $line");
    }
  }

  /// Stop the Frida session
  void stop() {
    if (_process != null) {
      _process!.kill();
      _process = null;
      debugPrint("🛑 Frida process killed.");
    }
  }

  /// Creates the Python adapter script in the temp directory.
  /// This ensures we always use the latest version of the script.
  Future<String> _createAdapterScript() async {
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, 'frida_adapter_v1.py'));
    final text = await rootBundle.loadString(
      '$fridaScriptsRoot/frida_adapter.py',
    );
    await file.writeAsString(text);
    return file.path;
  }
}

const String fridaScriptsRoot = 'assets/scripts/frida';

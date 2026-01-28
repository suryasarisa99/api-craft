import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:api_craft/traffic/interceptors/sources/android/adb/adb_models.dart';
import 'package:api_craft/traffic/interceptors/utils/cmd_utils.dart';
import 'package:flutter/foundation.dart';

/// Device client for executing commands on specific device
class AdbDeviceClient {
  final String deviceId;
  static List<String>? _rootCommand;

  Future<List<String>> get rootCommand async =>
      _rootCommand ?? _getRootCommand();

  AdbDeviceClient._(this.deviceId);

  /// Create device client instance (internal use)
  factory AdbDeviceClient.create(String deviceId) {
    return AdbDeviceClient._(deviceId);
  }

  /// Execute shell command
  Future<String> shell(List<String> command) async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'shell',
        ...command,
      ]);

      // if (result.exitCode != 0) {
      //   throw AdbException(
      //     'Shell command failed for ${command.join(' ')}: ${result.stderr}',
      //   );
      // }
      // if (result.exitCode != 0 &&
      //     !(command.contains('grep') && result.exitCode == 1)) {
      //   throw AdbException(
      //     'Shell command failed for ${command.join(' ')}: exit code: ${result.exitCode} ${result.stderr}',
      //   );
      // }

      return result.stdout.toString();
    } catch (e) {
      throw AdbException(
        'Shell command failed for ${command.join(' ')}: mssg: $e',
      );
    }
  }

  Future<String> rootShell(List<String> command) async {
    final x = await rootCommand;
    debugPrint("adb root cmd: ${[...x, ...command].join(' ')}");
    return shell([...x, ...command]);
  }

  /// Get device properties
  Future<Map<String, String>> getProperties() async {
    try {
      final result = await shell(['getprop']);
      return _parseProperties(result);
    } catch (e) {
      throw 'Failed to get properties: $e';
    }
  }

  /// List installed apps
  Future<List<AdbAppInfo>> listInstalledApps({
    bool includeSystemApps = false,
  }) async {
    try {
      final command = includeSystemApps
          ? ['pm', 'list', 'packages']
          : ['pm', 'list', 'packages', '-3'];

      final result = await shell(command);
      final apps = <AdbAppInfo>[];

      final lines = result.split('\n');
      for (final line in lines) {
        if (line.startsWith('package:')) {
          final packageName = line.substring(8).trim();
          if (packageName.isNotEmpty) {
            // Use efficient bulk method to get app info
            final appInfo = await _getAppInfoFast(packageName);
            apps.add(appInfo);
          }
        }
      }

      return apps;
    } catch (e) {
      throw AdbException('Failed to list apps: $e');
    }
  }

  Future<bool> isAppInstalled(String packageName) async {
    try {
      final result = await shell(['pm', 'list', 'packages', packageName]);
      return result.contains('package:$packageName');
    } catch (e) {
      return false;
    }
  }

  /// Install APK
  Future<void> install(String apkPath) async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'install',
        apkPath,
      ]);

      if (result.exitCode != 0) {
        throw AdbException('APK installation failed: ${result.stderr}');
      }
    } catch (e) {
      throw AdbException('APK installation failed: $e');
    }
  }

  Future<void> installFromStream(
    Stream<List<int>> apkStream, {
    bool replace = false,
  }) async {
    try {
      final process = await Process.start('adb', [
        '-s',
        deviceId,
        'install',
        if (replace) '-r', // Replace existing app
        '-t', // Allow test APKs
        '-S', // Read APK size from stdin
      ]);

      // Pipe the APK stream to the process
      apkStream.pipe(process.stdin);

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw AdbException('APK installation failed with exit code $exitCode');
      }
    } catch (e) {
      throw AdbException('APK installation failed: $e');
    }
  }

  Future<void> mkdir(String path) async {
    try {
      final result = await shell(['mkdir', '-p', path]);
      if (result.isNotEmpty) {
        throw AdbException('Failed to create directory: $result');
      }
    } catch (e) {
      throw AdbException('Failed to create directory: $e');
    }
  }

  /// Push file to device
  Future<void> push(String localPath, String remotePath, {int? mode}) async {
    try {
      final directory = remotePath.substring(0, remotePath.lastIndexOf('/'));
      if (directory.isNotEmpty) {
        await mkdir(directory); // Ensure directory exists
      }

      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'push',
        localPath,
        remotePath,
      ]);

      if (result.exitCode != 0) {
        throw AdbException('File push failed: ${result.stderr}');
      }
      if (mode != null) {
        shell(['chmod', mode.toRadixString(8), remotePath]);
      }
    } catch (e) {
      throw AdbException('File push failed: $e');
    }
  }

  Future<void> pushStream(
    Stream<List<int>> stream,
    String remotePath, {
    int? mode,
  }) async {
    debugPrint("push stream path: $remotePath");
    final directory = remotePath.substring(0, remotePath.lastIndexOf('/'));
    if (directory.isNotEmpty) {
      await mkdir(directory); // Ensure directory exists
    }
    Process? process;
    String adbStderr = ''; // Variable to store stderr output
    String adbStdout = ''; // Variable to store stdout output

    try {
      final x = await shell(['pwd']);
      debugPrint("cwd: $x");

      process = await Process.start('adb', [
        '-s',
        deviceId,
        'push',
        '-', // Use stdin for input
        remotePath,
      ]);

      // Listen to stderr and stdout *once*
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();

      // Pipe the stream to the process stdin
      await stream.pipe(process.stdin);
      await process.stdin.close(); // Crucial: Close stdin after piping

      // Wait for the process to complete and get captured output
      final exitCode = await process.exitCode;
      adbStderr = await stderrFuture; // Assign to the shared variable
      adbStdout = await stdoutFuture; // Assign to the shared variable

      if (exitCode != 0) {
        debugPrint('ADB push stderr: $adbStderr');
        debugPrint('ADB push stdout: $adbStdout');
        throw AdbException(
          'Stream push failed with exit code $exitCode: $adbStderr',
        );
      }

      // Set file permissions if specified
      if (mode != null) {
        await shell(['chmod', mode.toRadixString(8), remotePath]);
      }
    } catch (e) {
      debugPrint('Error caught during pushStream: $e');
      if (adbStderr.isNotEmpty) {
        debugPrint(
          'Captured ADB process stderr (from initial listen): $adbStderr',
        );
      }
      if (adbStdout.isNotEmpty) {
        debugPrint(
          'Captured ADB process stdout (from initial listen): $adbStdout',
        );
      }
      throw AdbException('Stream push failed: $e');
    }
  }

  Future<void> setProxy(int port) async {
    final ipAddress = await getIpAddress();
    try {
      final result = await shell([
        'settings',
        'put',
        'global',
        'http_proxy',
        '$ipAddress:$port',
      ]);
      if (result.isNotEmpty) {
        throw AdbException('Failed to set proxy: $result');
      }
    } catch (e) {
      throw AdbException('Failed to set proxy: $e');
    }
  }

  Future<void> clearProxy() async {
    try {
      final result = await shell([
        'settings',
        'put',
        'global',
        'http_proxy',
        ':0',
      ]);
      if (result.isNotEmpty) {
        throw AdbException('Failed to clear proxy: $result');
      }
    } catch (e) {
      throw AdbException('Failed to clear proxy: $e');
    }
  }

  Future<bool> hasProxyTo(int port) async {
    final ipAddress = await getIpAddress();
    try {
      final result = await shell(['settings', 'get', 'global', 'http_proxy']);
      if (result.trim() != '$ipAddress:$port') {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create reverse tunnel
  Future<void> reverseProxy(int devicePort, int hostPort) async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'reverse',
        'tcp:$devicePort',
        'tcp:$hostPort',
      ]);

      if (result.exitCode != 0) {
        throw AdbException('Reverse proxy failed: ${result.stderr}');
      }
    } catch (e) {
      throw AdbException('Reverse proxy failed: $e');
    }
  }

  Future<bool> hasReverseProxyTo(int devicePort) async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'reverse',
        '--list',
      ]);

      if (result.exitCode != 0) {
        throw 'List reverse proxies failed: ${result.stderr}';
      }

      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(' ');
        if (parts.length == 3) {
          final local = parts[1]; // e.g. tcp:8080
          final remote = parts[2]; // e.g. tcp:8080
          if (local == 'tcp:$devicePort' && remote == 'tcp:$devicePort') {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      throw 'Check reverse proxy failed: $e';
    }
  }

  /// Remove reverse tunnel
  Future<void> removeReverseProxy(int devicePort) async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'reverse',
        '--remove',
        'tcp:$devicePort',
      ]);

      if (result.exitCode != 0) {
        throw AdbException('Remove reverse proxy failed: ${result.stderr}');
      }
    } catch (e) {
      throw AdbException('Remove reverse proxy failed: $e');
    }
  }

  static const rootCmds = [
    ['id'],
    ['su', '-c', 'id'],
    ['su', 'root', 'id'],
  ];

  /// Get root command prefix
  Future<List<String>> _getRootCommand() async {
    try {
      final cmdsPromise = rootCmds.map((cmd) => shell(cmd)).toList();
      final results = await Future.wait(cmdsPromise);

      for (int i = 0; i < results.length; i++) {
        final output = results[i];
        if (output.contains('uid=0')) {
          _rootCommand = rootCmds[i].sublist(0, rootCmds[i].length - 1);
          debugPrint('Root command found: $_rootCommand');
          return _rootCommand!;
        }
      }
      throw AdbException('Device does not have root access');
    } catch (e) {
      throw AdbException('Device does not have root access');
    }
  }

  /// List directory contents
  Future<List<FileEntry>> readdir(String path) async {
    try {
      final result = await shell(['ls', '-la', path]);
      final entries = <FileEntry>[];
      debugPrint("ls result: $result");

      final lines = result.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('total')) {
          continue;
        }

        // Parse ls -la output: permissions links owner group size date time name
        // Example: -r-xr-xr-x 1 shell shell 56858936 2025-07-21 22:27 adirf-server-16.6.1
        final trimmedLine = line.trim();
        final parts = trimmedLine.split(RegExp(r'\s+'));

        if (parts.length >= 8) {
          // Changed from 9 to 8
          final permissions = parts[0];
          final size = int.tryParse(parts[4]) ?? 0;

          // The filename starts after the time column (index 7)
          // Format: permissions links owner group size date time filename...
          final name = parts.sublist(7).join(' ');

          // Skip . and .. entries
          if (name == '.' || name == '..') {
            continue;
          }

          // Convert permissions to mode (simple approximation)
          int mode = 0;
          if (permissions.contains('x')) {
            mode |= 0x00111; // Executable
          }

          debugPrint(
            "parsed entry: '$name', size: $size, mode: $mode, permissions: $permissions",
          );

          entries.add(
            FileEntry(
              name: name,
              size: size,
              mode: mode,
              permissions: permissions,
            ),
          );
        } else {
          debugPrint(
            "Skipping malformed line (${parts.length} parts): $trimmedLine",
          );
        }
      }

      return entries;
    } catch (e) {
      throw AdbException('Failed to list directory: $e');
    }
  }

  /// Execute shell command in background (non-blocking)
  Future<Future<void> Function()> shellBackground(List<String> command) async {
    try {
      final process = await Process.start('adb', [
        '-s',
        deviceId,
        'shell',
        ...command,
      ]);

      // Setup logging for background process
      process.stdout.listen(
        (data) => debugPrint('ADB BG: ${String.fromCharCodes(data)}'),
      );
      process.stderr.listen(
        (data) => debugPrint('ADB BG Error: ${String.fromCharCodes(data)}'),
      );

      // Return a function to kill the process
      return () async {
        process.kill();
        await process.exitCode;
      };
    } catch (e) {
      throw AdbException('Background shell command failed: $e');
    }
  }

  /// Start an Activity on the device
  Future<void> startActivity(
    String activity, {
    Map<String, String>? extras,
    String? action,
    String? category,
    String? dataUri,
  }) async {
    try {
      final command = ['am', 'start'];

      // Add action if provided
      if (action != null) {
        command.addAll(['-a', action]);
      }

      // Add category if provided
      if (category != null) {
        command.addAll(['-c', category]);
      }

      // Add data URI if provided
      if (dataUri != null) {
        command.addAll(['-d', dataUri]);
      }

      // Add extras if provided
      if (extras != null) {
        for (final entry in extras.entries) {
          command.addAll(['--es', entry.key, entry.value]);
        }
      }

      // Add the activity component
      command.add(activity);

      final result = await shell(command);
      debugPrint('Activity started: $activity');
      debugPrint('Result: $result');
    } catch (e) {
      throw AdbException('Failed to start activity $activity: $e');
    }
  }

  /// Bring an activity to front (start and bring to front)
  Future<void> bringToFront(String activity) async {
    try {
      final command = [
        'am',
        'start',
        '-f', '0x10200000', // Flags: NEW_TASK | SINGLE_TOP
        activity,
      ];

      final result = await shell(command);
      debugPrint('Activity brought to front: $activity');
      debugPrint('Result: $result');
    } catch (e) {
      throw AdbException('Failed to bring activity to front $activity: $e');
    }
  }

  /// Parse properties output
  Map<String, String> _parseProperties(String output) {
    final properties = <String, String>{};
    final lines = output.split('\n');

    for (final line in lines) {
      final match = RegExp(r'^\[(.+?)\]: \[(.*?)\]$').firstMatch(line);
      if (match != null) {
        properties[match.group(1)!] = match.group(2)!;
      }
    }

    return properties;
  }

  /// Get app information efficiently (faster than pm dump)
  Future<AdbAppInfo> _getAppInfoFast(String packageName) async {
    try {
      // For speed, we'll just use the package name as the name and skip version lookup
      // Version lookup via pm dump is too slow for listing many apps
      // If detailed info is needed, it can be fetched individually later

      String name = packageName;

      // Extract a readable name from package name if possible
      final parts = packageName.split('.');
      if (parts.length > 1) {
        // Use the last part as a basic name, capitalize first letter
        final lastPart = parts.last;
        if (lastPart.isNotEmpty) {
          name = lastPart[0].toUpperCase() + lastPart.substring(1);
        }
      }

      return AdbAppInfo(
        packageName: packageName,
        name: name,
        version: 'Unknown',
      );
    } catch (e) {
      // Fallback to minimal info
      return AdbAppInfo(
        packageName: packageName,
        name: packageName,
        version: 'Unknown',
      );
    }
  }

  /// Check if a port is open on the device (lightweight version)
  Future<bool> isPortOpen(int port) async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'shell',
        'cat',
        '/proc/net/tcp',
      ]);

      if (result.exitCode != 0) return false;

      final lines = result.stdout.toString().split('\n');
      for (final line in lines.skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 2) continue;

        final localAddress = parts[1]; // hex IP:PORT
        final portHex = port.toRadixString(16).padLeft(4, '0').toUpperCase();
        if (localAddress.endsWith(portHex)) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Open TCP connection to device port (for port checking)
  Future<Socket> openTcp(int port) async {
    try {
      // Use a random local port to avoid conflicts
      final localPort = 20000 + DateTime.now().millisecondsSinceEpoch % 10000;

      final forwardResult = await Process.run('adb', [
        '-s',
        deviceId,
        'forward',
        'tcp:$localPort',
        'tcp:$port',
      ]);

      if (forwardResult.exitCode != 0) {
        throw AdbException('Port forward failed: ${forwardResult.stderr}');
      }

      Socket? socket;
      try {
        // Try to connect to the forwarded port with a short timeout
        socket = await Socket.connect(
          'localhost',
          localPort,
        ).timeout(Duration(milliseconds: 500));

        return socket;
      } catch (e) {
        // Clean up the port forward on connection failure
        await _cleanupPortForward(localPort);
        rethrow;
      }
    } catch (e) {
      throw AdbException('TCP connection failed: $e');
    }
  }

  /// Clean up port forward and ensure it's removed
  Future<void> _cleanupPortForward(int localPort) async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'forward',
        '--remove',
        'tcp:$localPort',
      ]).timeout(Duration(seconds: 2));

      if (result.exitCode != 0) {
        debugPrint(
          'Warning: Failed to remove port forward tcp:$localPort: ${result.stderr}',
        );
      }
    } catch (e) {
      debugPrint('Warning: Port forward cleanup failed for tcp:$localPort: $e');
    }
  }

  /// Clean up all port forwards for this device
  Future<void> cleanupAllPortForwards() async {
    try {
      final result = await Process.run('adb', [
        '-s',
        deviceId,
        'forward',
        '--remove-all',
      ]).timeout(Duration(seconds: 3));

      if (result.exitCode != 0) {
        debugPrint(
          'Warning: Failed to remove all port forwards: ${result.stderr}',
        );
      } else {
        debugPrint('Cleaned up all port forwards for device $deviceId');
      }
    } catch (e) {
      debugPrint('Warning: Cleanup all port forwards failed: $e');
    }
  }
}

class AdbException implements Exception {
  final String message;

  AdbException(this.message);

  @override
  String toString() => 'ADB Exception: $message';
}

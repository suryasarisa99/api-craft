import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

class ClientExtraInfo {
  final String processPath;
  final int pid;
  final String? appName;
  int timestamp;

  ClientExtraInfo({
    required this.processPath,
    required this.pid,
    required this.appName,
    required this.timestamp,
  });
}

class ClientInfoService {
  ClientInfoService._();
  static final diff = 30 * 1000; //30seconds
  static final Map<String, ClientExtraInfo> infos = {};

  static void addInfo(ClientExtraInfo info) {
    infos[info.processPath] = info;
  }

  static ClientExtraInfo? getCachedInfo(String ip, int port) {
    final info = infos['$ip:$port'];
    if (info != null &&
        info.timestamp + diff > DateTime.now().millisecondsSinceEpoch) {
      //update time and return
      info.timestamp = DateTime.now().millisecondsSinceEpoch;
      return info;
    }
    return null;
  }

  static Future<ClientExtraInfo?> resolveInfo(String ip, int port) async {
    final info = await _resolveProcessInfo(port, ip);
    if (info == null) return null;
    final clientInfo = ClientExtraInfo(
      processPath: info.processPath,
      pid: info.pid,
      appName: _getAppName(info.processPath),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    addInfo(clientInfo);
    return clientInfo;
  }

  static Future<ClientExtraInfo?> getInfo(String ip, int port) async {
    return getCachedInfo(ip, port) ?? await resolveInfo(ip, port);
  }

  static Future<({int pid, String processPath})?> _resolveProcessInfo(
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

  static String? _getAppName(String path) {
    String? appBundlePath;
    final index = path.lastIndexOf('.app/');
    if (index != -1) {
      appBundlePath = path.substring(0, index + 4);
    } else if (path.endsWith('.app')) {
      appBundlePath = path;
    }
    if (appBundlePath != null) {
      return p.basenameWithoutExtension(appBundlePath);
    }
    return null;
  }
}

class AppIconService {
  AppIconService._();

  static final Map<String, Uint8List> _bytesCache = {};

  /// Directory under system temp where icons are persisted.
  static Directory get _cacheDir =>
      Directory('${Directory.systemTemp.path}/mitmui_app_icon_cache');

  static Future<Uint8List?> getAppIcon(String processPath) async {
    final key = processPath;
    if (_bytesCache.containsKey(key)) {
      return _bytesCache[key];
    }

    String? appBundlePath;
    if (processPath.contains('.app/')) {
      final index = processPath.indexOf('.app/');
      appBundlePath = processPath.substring(0, index + 4);
    } else if (processPath.endsWith('.app')) {
      appBundlePath = processPath;
    }

    if (appBundlePath == null) return null;

    final appName = p.basenameWithoutExtension(appBundlePath);
    // Unique key for cache file
    final cacheKey = '${appName}_${appBundlePath.hashCode}';
    final cacheFile = File(p.join(_cacheDir.path, '$cacheKey.png'));

    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }

    // Check disk cache
    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      _bytesCache[key] = bytes;
      return bytes;
    }

    try {
      final plistPath = p.join(appBundlePath, 'Contents', 'Info.plist');
      if (!File(plistPath).existsSync()) return null;

      final result = await Process.run('defaults', [
        'read',
        plistPath,
        'CFBundleIconFile',
      ]);
      var iconName = (result.stdout as String).trim();
      if (iconName.isEmpty) return null;

      if (!iconName.endsWith('.icns')) {
        iconName += '.icns';
      }
      final iconPath = p.join(appBundlePath, 'Contents', 'Resources', iconName);

      if (!File(iconPath).existsSync()) return null;

      // Convert to png using sips
      await Process.run('sips', [
        '-s',
        'format',
        'png',
        iconPath,
        '--out',
        cacheFile.path,
      ]);

      if (await cacheFile.exists()) {
        final bytes = await cacheFile.readAsBytes();
        _bytesCache[key] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint("Error loading app icon: $e");
    }

    return null;
  }
}

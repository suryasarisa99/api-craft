import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class BrowserUtils {
  static const _firefoxBasedBrowsers = [
    'firefox',
    'firefox developer edition',
    'firefox nightly',
    'waterfox',
    'pale moon',
    'basilisk',
    'zen',
    'librewolf',
    'icecat',
    'floorp',
    'tenfourfox',
    'seamonkey',
    'mull',
    'serpent',
    'conkeror',
    'otter',
    'k-meleon',
  ];
  static const _chromiumBasedBrowsers = [
    'google chrome',
    'chromium',
    'brave',
    'edge',
    'opera',
    'vivaldi',
    'arc',
    'cromite',
    'bromite',
    'iridium',
    'ungoogled chromium',
    'browser-os',
    'yandex',
    'atlas',
    'comet',
  ];
  static List<String> get firefoxBasedBrowsers =>
      ApplicationUtils.avilableApplications(_firefoxBasedBrowsers);
  static List<String> get chromiumBasedBrowsers =>
      ApplicationUtils.avilableApplications(_chromiumBasedBrowsers);
}

class ApplicationUtils {
  static List<String> avilableApplications(List<String> keywords) {
    // 1. Define the paths where browsers usually live
    final commonPaths = [
      '/Applications',
      '${Platform.environment['HOME']}/Applications',
    ];

    final Set<String> foundApps = {};

    for (final pathString in commonPaths) {
      final dir = Directory(pathString);
      if (!dir.existsSync()) continue;

      try {
        // 2. List the directory contents (Non-recursive = Safe from Burp Suite)
        final List<FileSystemEntity> entities = dir.listSync();

        for (final entity in entities) {
          final filename = p.basename(entity.path);

          // Only check .app folders
          if (!filename.endsWith('.app')) continue;

          final appName = filename.replaceFirst('.app', '');
          final lowerAppName = appName.toLowerCase();

          // 3. Check if this app matches any of your keywords
          // We use 'contains' to match "Firefox Developer Edition" with "firefox"
          for (final keyword in keywords) {
            if (lowerAppName.contains(keyword.toLowerCase())) {
              foundApps.add(appName);
              break; // Found a match for this app, move to next file
            }
          }
        }
      } catch (e) {
        // Permission errors might happen in some restricted folders
        debugPrint("Error scanning $pathString: $e");
      }
    }

    return foundApps.toList();
  }

  static Future<String?> findPathByBundleId(String bundleId) async {
    try {
      // mdfind is the fastest way to resolve an ID to a Path
      final result = await Process.run('mdfind', [
        'kMDItemCFBundleIdentifier == "$bundleId"',
      ]);

      final output = result.stdout.toString().trim();

      if (output.isEmpty) return null;

      // mdfind might return multiple versions.
      // Usually the shortest path (e.g. /Applications/Chrome.app) is the main one.
      final paths = output.split('\n');

      // Sort by length to prefer "/Applications/App.app" over "/Users/x/Downloads/App.app"
      paths.sort((a, b) => a.length.compareTo(b.length));

      return paths.first;
    } catch (e) {
      return null;
    }
  }
}

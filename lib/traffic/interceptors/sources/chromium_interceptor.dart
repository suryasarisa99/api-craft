import 'dart:io';

import 'package:api_craft/traffic/interceptors/utils/browser_utils.dart';
import 'package:api_craft/traffic/interceptors/models/interceptor_model.dart';
import 'package:api_craft/traffic/interceptors/utils/cmd_utils.dart';
import 'package:flutter/material.dart';

class ChromiumInterceptor extends Interceptor {
  @override
  get name => "Chromium";

  @override
  get description => "Launches Chromium-based browsers with proxy settings.";
  @override
  get tags => ["chromium", "browser"];

  @override
  getPreOptions() {
    return [
      (label: 'New Window', value: {'newWindow': true}),
      // (label: 'Incognito Mode', value: {'incognito': true, 'newWindow': true}),
      (label: 'Guest Mode', value: {'guest': true, 'newWindow': true}),
      (label: 'Global', value: {}),
    ];
  }

  @override
  getOptions() async {
    return BrowserUtils.chromiumBasedBrowsers;
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
    final preOption = config.preOption as Map<dynamic, dynamic>;
    final option = config.option as String;
    if (Platform.isMacOS) {
      final cmd = [
        'open',
        '-a',
        '"$option"',
        if (preOption['newWindow'] ?? false) '--new',
        '--args',
        if (preOption['incognito'] ?? false) '--incognito',
        if (preOption['guest'] ?? false) '--guest',
        '--proxy-server="http=${config.proxyHost}:${config.proxyPort};https=${config.proxyHost}:${config.proxyPort}"',
      ].join(' ');
      runCmd(cmd);
    }
  }
}

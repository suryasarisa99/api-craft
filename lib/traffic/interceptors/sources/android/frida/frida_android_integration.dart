import 'dart:async';

import 'package:api_craft/traffic/interceptors/sources/android/adb/adb_client.dart';
import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_android_intercept.dart';
import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_script_build.dart';
import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_session.dart';
import 'package:api_craft/traffic/interceptors/utils/cmd_utils.dart';
import 'package:api_craft/traffic/interceptors/utils/get_certificate.dart';
import 'package:flutter/material.dart';

class FridaService {
  final String deviceId;
  final String envPath;

  // late initialized members
  late final FridaSession fridaSession = FridaSession(
    envPath: envPath,
    deviceId: deviceId,
  );
  late final adbDeviceClient = AdbClient.getDevice(deviceId);

  FridaService({required this.envPath, required this.deviceId});

  Future<Stream<String>> launchApp(String packageId) async {
    final fridaScript = await createScript();
    return fridaSession.startSession(
      packageId: packageId,
      script: fridaScript,
      onMessage: (m) {
        debugPrint("📩 Frida Message: $m");
      },
      onError: (err) {
        debugPrint("❌ Frida Error: $err");
      },
      onStatus: (e) {
        debugPrint("🔵 Frida Status: $e");
      },
    );
  }

  Future<List<AndroidAppInfo>> getAppList() {
    return fridaSession.getAppList();
  }

  // Future<bool> isFridaRunning() async {
  //   try {
  //     final adbDeviceClient = AdbClient.getDevice(deviceId);
  //     final result = await adbDeviceClient.rootShell([
  //       'ps -e | grep frida-server',
  //     ]);
  //     if (result.trim().isNotEmpty) {
  //       debugPrint("frida server is already running, result: $result");
  //       return true;
  //     }
  //   } catch (e) {
  //     debugPrint("Error checking Frida status: $e");
  //     return false;
  //   }
  //   return false;
  // }
  Future<bool> isFridaRunning() async {
    try {
      final pid = await getFridaServerPid();
      if (pid != null) {
        debugPrint("frida server is already running with pid: $pid");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error checking Frida status: $e");
      return false;
    }
  }

  Future<int?> getFridaServerPid() async {
    try {
      final result = await adbDeviceClient.rootShell(['pidof frida-server']);
      if (result.trim().isNotEmpty) {
        debugPrint("frida server pid: $result");
        return int.parse(result.trim());
      }
    } catch (e) {
      debugPrint("Error getting Frida PID: $e");
      return null;
    }
    return null;
  }

  Future<void> stopFridaServer({int? processId}) async {
    try {
      final pid = processId ?? await getFridaServerPid();
      if (pid != null) {
        final result = await adbDeviceClient.rootShell(['kill -9 $pid']);
        debugPrint("Stopped frida server, result: $result");
      } else {
        debugPrint("Frida server not running.");
      }
    } catch (e) {
      debugPrint("Error stopping Frida server: $e");
    }
  }

  // runs frida server in android device,returns pid
  Future<int?> startFridaServer() async {
    try {
      //check frida is already running
      final isRunning = await isFridaRunning();
      if (isRunning) return getFridaServerPid();
      final result = await adbDeviceClient.rootShell([
        'nohup /data/local/tmp/frida-server >/dev/null 2>&1 &',
      ]);
      debugPrint("Started frida server, result: $result");
      // wait 2 sec
      await Future.delayed(const Duration(seconds: 2));
      return getFridaServerPid();
    } catch (e) {
      debugPrint("Error starting Frida server: $e");
    }
    return null;
  }

  static Future<String> createScript() async {
    final certificate = await getCertificatePem();
    final ipAddress = await getIpAddress();
    return buildAndroidFridaScript(certificate, ipAddress, 8080, [
      80,
      443,
    ], false);
  }
}

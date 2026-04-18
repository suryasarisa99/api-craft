import 'dart:io';

import 'package:api_craft/traffic/interceptors/sources/android/adb/adb_device_client.dart';
import 'package:api_craft/traffic/interceptors/sources/android/adb/adb_models.dart';
import 'package:flutter/material.dart';

//1. implement cache device name

const androidTemp = '/data/local/tmp';
const systemCaPath = '/system/etc/security/cacerts';
const emulatorHostIps = [
  '10.0.2.2', // Standard emulator localhost ip
  '10.0.3.2', // Genymotion localhost ip
];

class AdbClient {
  /// Check if ADB is available
  static Future<bool> isAdbAvailable() async {
    try {
      final result = await Process.run('adb', ['version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get list of connected devices
  static Future<List<AdbDevice>> getDevices() async {
    try {
      final result = await Process.run('adb', ['devices']);
      if (result.exitCode != 0) {
        debugPrint('adb devices failed with code ${result.exitCode}: ${result.stderr}');
        return <AdbDevice>[];
      }
      debugPrint("adb devices output: ${result.stdout}");
      final lines = result.stdout.toString().split('\n');
      final devices = <AdbDevice>[];

      for (final line in lines) {
        if (line.contains('\t')) {
          final parts = line.split('\t');
          if (parts.length >= 2) {
            final deviceId = parts[0].trim();
            final status = parts[1].trim();
            if (deviceId.isNotEmpty && status.isNotEmpty) {
              devices.add(AdbDevice(id: deviceId, status: status));
            }
          }
        }
      }

      return devices;
    } catch (e) {
      debugPrint('Error getting adb devices: $e');
      return <AdbDevice>[];
    }
  }

  /// Get device client for specific device
  static AdbDeviceClient getDevice(String deviceId) {
    return AdbDeviceClient.create(deviceId);
  }
}

/// Helper function to create device details list with proper types
Future<List<AdbDevice>> getConnectedDevices() async {
  try {
    final devices = await AdbClient.getDevices();
    late final List<AdbDevice> connectedDevices;
    connectedDevices = devices.where((d) => d.status == 'device').toList();

    return connectedDevices;
  } catch (e) {
    debugPrint('Direct ADB unavailable: $e');
    return <AdbDevice>[];
  }
}

/// Get device name with caching
final Map<String, String> _deviceNameCache = {};

Future<String> getDeviceName(
  AdbDeviceClient deviceClient,
  String deviceId,
) async {
  if (_deviceNameCache.containsKey(deviceId)) {
    return _deviceNameCache[deviceId]!;
  }

  String deviceName;
  try {
    if (deviceId.startsWith('emulator-')) {
      final props = await deviceClient.getProperties();

      final avdName =
          props['ro.boot.qemu.avd_name'] ?? props['ro.kernel.qemu.avd_name'];
      final osVersion = props['ro.build.version.release'];

      deviceName =
          avdName?.replaceAll('_', ' ') ??
          'Android ${osVersion ?? 'Unknown'} emulator';
    } else {
      try {
        final name = await deviceClient.shell([
          'settings',
          'get',
          'global',
          'device_name',
        ]);

        if (name.trim().isNotEmpty && !name.contains('null')) {
          deviceName = name.trim();
        } else {
          final props = await deviceClient.getProperties();
          deviceName = props['ro.product.model'] ?? deviceId;
        }
      } catch (e) {
        final props = await deviceClient.getProperties();
        deviceName = props['ro.product.model'] ?? deviceId;
      }
    }
  } catch (e) {
    print('Error getting device name for $deviceId: $e');
    deviceName = deviceId;
  }

  _deviceNameCache[deviceId] = deviceName;
  return deviceName;
}

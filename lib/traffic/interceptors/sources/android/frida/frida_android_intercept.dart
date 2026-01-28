import 'dart:async';
import 'dart:io';
import 'package:api_craft/traffic/interceptors/models/interceptor_model.dart';
import 'package:api_craft/traffic/interceptors/sources/android/adb/adb_client.dart';
import 'package:api_craft/traffic/interceptors/sources/android/adb/adb_models.dart';
import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_android_integration.dart';
import 'package:path/path.dart' as p;

class FridaAndroidInterceptor extends Interceptor {
  late FridaService fridaService;
  @override
  get name => "Frida Android";

  @override
  get description =>
      "Uses Frida to hook into Android apps for dynamic analysis.";

  @override
  get tags => ["frida", "android", "dynamic analysis"];

  @override
  Future<List<AdbDevice>> getOptions() async {
    return AdbClient.getDevices();
  }

  @override
  getSubOptions(dynamic deviceId) async {
    return null;
  }

  @override
  launch(LaunchConfig config) async {
    return null;
  }

  FridaService createFridaService(dynamic deviceId) {
    const myPythonEnv = '/Users/jayasuryasarisa/ws/py/burp-test/fridaenv';
    fridaService = FridaService(envPath: myPythonEnv, deviceId: deviceId);
    return fridaService;
  }
}

class AndroidAppInfo {
  final String name;
  final String packageName;
  // Can be converted to Image.memory(base64Decode(...))
  final String iconBase64;

  AndroidAppInfo({
    required this.name,
    required this.packageName,
    required this.iconBase64,
  });
}

class PythonEnv {
  /// Resolves the python executable from a given environment folder.
  /// Handles Windows (Scripts/python.exe) and Mac/Linux (bin/python).
  static String getExePath(String envFolderPath) {
    String pythonPath;

    if (Platform.isWindows) {
      pythonPath = p.join(envFolderPath, 'Scripts', 'python.exe');
    } else {
      pythonPath = p.join(envFolderPath, 'bin', 'python');
    }

    if (!File(pythonPath).existsSync()) {
      throw Exception(
        "Python executable not found at: $pythonPath\nMake sure the environment path is correct.",
      );
    }

    return pythonPath;
  }
}

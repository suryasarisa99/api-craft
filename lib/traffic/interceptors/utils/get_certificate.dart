import 'dart:io';
import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/traffic/interceptors/utils/cmd_utils.dart';
import 'package:path/path.dart' as p;

Future<String> getCertificatePem() async {
  final certPath = getCertificatePath();
  final certFile = File(certPath);
  if (await certFile.exists()) {
    return await certFile.readAsString();
  } else {
    throw Exception("Certificate file not found at $certPath");
  }
}

String getCertificatePath() {
  final curr = getCertificationsDirPath();
  return p.join(curr, '$kAppName-ca-cert.pem');
}

String getCertificationsDirPath() {
  final home = getHomeDirectory();
  return p.join(home, kAppName);
}

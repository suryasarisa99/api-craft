import 'dart:io';
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
  final curr = Directory.current.path;
  return p.join(curr, 'mockttp-ca-cert.pem');
}

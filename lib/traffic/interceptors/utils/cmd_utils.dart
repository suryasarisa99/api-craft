import 'dart:io';
import 'package:flutter/material.dart';

void runCmd(String command) async {
  debugPrint("Executing command: $command");
  if (Platform.isMacOS) {
    final result = await Process.run('bash', ['-c', command]);
    //
    final out = (result.stdout as String).trim();
    if (out.isNotEmpty) {
      debugPrint('output: $out');
    }
    final err = (result.stderr as String).trim();
    if (err.isNotEmpty) {
      debugPrint('error: $err');
    }
  }
}

void runInTerminal(String command) async {
  debugPrint("Running in terminal: $command");
  if (Platform.isMacOS) {
    // Create a temporary script
    final script = File('/tmp/run_cmd.sh');
    await script.writeAsString('#!/bin/bash\n$command\n');

    // Make it executable
    await Process.run('chmod', ['+x', script.path]);

    // Open Terminal and execute the script
    Process.run('open', ['-a', 'Terminal', script.path]);
  } else if (Platform.isWindows) {
    // For Windows, you can use 'start' command to open cmd
    Process.run('cmd', ['/c', 'start', 'cmd', '/k', command]);
  } else if (Platform.isLinux) {
    // For Linux, you might use gnome-terminal or xterm
    Process.run('gnome-terminal', ['--', 'bash', '-c', '$command; exec bash']);
    // x-terminal-emulator
  }
}

String getHomeDirectory() {
  if (Platform.isMacOS || Platform.isLinux) {
    // Get the HOME environment variable on Mac/Linux
    return Platform.environment['HOME']!;
  } else if (Platform.isWindows) {
    // Get the USERPROFILE environment variable on Windows
    return Platform.environment['USERPROFILE']!;
  }
  throw UnsupportedError('Unsupported operating system.');
}

Future<String> getIpAddress() async {
  final cmd =
      """ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print \$2}'""";

  final result = await Process.run('bash', ['-c', cmd]);

  if (result.exitCode != 0) {
    throw Exception('Failed to get IP address: ${result.stderr}');
  }

  final output = (result.stdout as String).trim();
  if (output.isEmpty) return '';

  // Take the first IP if multiple are returned
  final ipAddress = output.split('\n').first;
  debugPrint("getIpAddress result: $ipAddress");
  return ipAddress;
}

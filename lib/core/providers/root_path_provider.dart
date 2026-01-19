import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final rootPathProvider = FutureProvider<String>((ref) async {
  final docsDir = await getApplicationDocumentsDirectory();

  final workspacesPath = p.join(docsDir.path, 'MyNetworkApp', 'workspaces');
  final workspacesDir = Directory(workspacesPath);

  if (!await workspacesDir.exists()) {
    await workspacesDir.create(recursive: true);
    final defaultWorkspacePath = p.join(workspacesPath, 'api-craft');
    await Directory(defaultWorkspacePath).create();
    await File(p.join(defaultWorkspacePath, 'workspace.json')).writeAsString(
      '{"name": "API Craft", "type": "workspace", "version": "1"}',
    );
    await File(p.join(defaultWorkspacePath, 'hello.json')).writeAsString(
      '{"method": "GET", "url": "https://api.example.com", "name": "Hello World"}',
    );
  }

  return workspacesPath;
});

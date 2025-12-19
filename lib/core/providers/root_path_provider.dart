import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final rootPathProvider = FutureProvider<String>((ref) async {
  final docsDir = await getApplicationDocumentsDirectory();

  final collectionsPath = p.join(docsDir.path, 'MyNetworkApp', 'collections');
  final collectionsDir = Directory(collectionsPath);

  if (!await collectionsDir.exists()) {
    await collectionsDir.create(recursive: true);
    final defaultCollectionPath = p.join(collectionsPath, 'api-craft');
    await Directory(defaultCollectionPath).create();
    await File(p.join(defaultCollectionPath, 'collection.json')).writeAsString(
      '{"name": "API Craft", "type": "collection", "version": "1"}',
    );
    await File(p.join(defaultCollectionPath, 'hello.json')).writeAsString(
      '{"method": "GET", "url": "https://api.example.com", "name": "Hello World"}',
    );
  }

  return collectionsPath;
});

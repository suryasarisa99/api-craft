import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:api_craft/objectbox.g.dart'; // Corrected import

class ObjectBox {
  /// The Store of this app.
  late final Store store;

  ObjectBox._create(this.store);

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, "obx-api-craft");
    debugPrint("ObjectBox DB Path: $dbPath");
    final store = await openStore(directory: dbPath);
    return ObjectBox._create(store);
  }
}

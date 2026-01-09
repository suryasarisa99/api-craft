import 'package:api_craft/core/database/objectbox.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<Future<ObjectBox>>((ref) async {
  return await ObjectBox.create();
});

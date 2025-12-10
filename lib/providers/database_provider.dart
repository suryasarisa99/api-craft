import 'package:api_craft/db/database_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

final databaseProvider = Provider<Future<Database>>((ref) async {
  return DatabaseHelper.initDB();
});

// database_helper.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

// Provider to give synchronous access to DB after app start

class DatabaseHelper {
  static Future<Database> initDB() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'api_craft_meta.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. Table to store the LIST of collections
        await db.execute('''
          CREATE TABLE collections (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL, -- 'database' or 'filesystem'
            path TEXT -- Null if database, actual path if filesystem
          )
        ''');

        // 2. Table to store NODES (Requests/Folders) for DB-based collections
        // Notice 'collection_id'. This allows multiple collections to live in one table.
        await db.execute('''
          CREATE TABLE nodes (
            id TEXT PRIMARY KEY,
            collection_id TEXT NOT NULL, 
            parent_id TEXT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            method TEXT,
            url TEXT,
            body TEXT,
            sort_order INTEGER DEFAULT 0,
            FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }
}

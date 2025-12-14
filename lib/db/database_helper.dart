// database_helper.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

// Provider to give synchronous access to DB after app start

class Tables {
  static const String collections = 'collections';
  static const String nodes = 'nodes';
  static const String history = 'request_history';

  static const queries = (
    collections:
        '''
      CREATE TABLE $collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'database' or 'filesystem'
        path TEXT -- Null if database, actual path if filesystem
      )
    ''',
    nodes:
        '''
      CREATE TABLE $nodes (
       -- 1. Identity & Tree
    id TEXT PRIMARY KEY,
    collection_id TEXT NOT NULL,
    parent_id TEXT,
    sort_order INTEGER DEFAULT 0,
    type TEXT NOT NULL, -- 'folder' or 'request'

    -- 2. Common Details (Shared by Both)
    name TEXT NOT NULL,
    description TEXT,     -- Searchable! (Was hidden in config)
    headers TEXT,         -- JSON: List of {key, val, enabled}
    auth TEXT,            -- JSON: {type: 'bearer', token: '...'}
    
    -- 3. Folder Specific
    variables TEXT,       -- JSON: Map of env vars

    -- 4. Request Specific
    method TEXT,
    url TEXT,
    request_type TEXT,    -- 'http', 'graphql','wc','grpc' etc.
    query_parameters TEXT, -- JSON: List of {key, val, enabled}
    body TEXT,
    status_code INTEGER
      )
    ''',
    history:
        '''CREATE TABLE $history (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL,
  status_code INTEGER,
  status_message TEXT,
  protocol_version TEXT,
  headers TEXT,        -- JSON: List of {key, val}
  body_bytes BLOB,    -- Raw bytes
  body_type TEXT,    -- 'text', 'json', 'xml', etc.
  body_base64 TEXT,   -- Base64 encoded string
  body TEXT,          -- UTF8 String
  executed_at INTEGER NOT NULL,
  duration_ms INTEGER,
  --  response_size INTEGER,
  FOREIGN KEY(request_id) REFERENCES nodes(id) ON DELETE CASCADE
);

-- Index for faster lookups/sorting
-- CREATE INDEX idx_history_req_date ON $history(request_id, executed_at DESC);
''',
  );

  static List<String> queriesList = [
    queries.collections,
    queries.nodes,
    queries.history,
  ];
  static List<String> tableNames = [collections, nodes, history];

  static Future<void> createAllTables(Database db) async {
    for (var query in queriesList) {
      await db.execute(query);
    }
  }

  static Future<void> dropAllTables(Database db) async {
    for (var table in tableNames) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
  }
}

class DatabaseHelper {
  static Future<Database> initDB() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'api_craft_meta.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        Tables.createAllTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // for development only
        await Tables.dropAllTables(db);
        Tables.createAllTables(db);
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        // for development only
        await Tables.dropAllTables(db);
        Tables.createAllTables(db);
      },
    );
  }
}

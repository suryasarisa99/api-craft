// database_helper.dart
import 'package:api_craft/core/constants/globals.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// Provider to give synchronous access to DB after app start

class Tables {
  static const String collections = 'collections';
  static const String nodes = 'nodes';
  static const String history = 'request_history';
  static const String environments = 'environments';
  static const String cookieJars = 'cookie_jars';
  static const String websocketMessages = 'websocket_messages';
  static const String websocketSessions = 'websocket_sessions';

  static const queries = (
    collections:
        '''
      CREATE TABLE $collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'database' or 'filesystem'
        path TEXT, -- Null if database, actual path if filesystem
        selected_env_id TEXT,
        selected_jar_id TEXT
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
    body_type TEXT,
    scripts TEXT,
    status_code INTEGER
      )
    ''',
    history: '''CREATE TABLE $history (
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
  error_message TEXT, -- Error message if failed
  --  response_size INTEGER,
  FOREIGN KEY(request_id) REFERENCES nodes(id) ON DELETE CASCADE
);
''',
    environments:
        '''
      CREATE TABLE $environments (
        id TEXT PRIMARY KEY,
        collection_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color INTEGER,
        variables TEXT, -- JSON: List of {key, val, enabled}
        is_shared INTEGER DEFAULT 0,
        is_global INTEGER DEFAULT 0
      )
    ''',
    cookieJars:
        '''
      CREATE TABLE $cookieJars (
        id TEXT PRIMARY KEY,
        collection_id TEXT NOT NULL,
        name TEXT NOT NULL,
        cookies TEXT -- JSON: List of CookieDef
      )
    ''',
    websocketSessions:
        '''
      CREATE TABLE $websocketSessions (
        id TEXT PRIMARY KEY,
        request_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        url TEXT,
        FOREIGN KEY(request_id) REFERENCES nodes(id) ON DELETE CASCADE
      )
    ''',
    websocketMessages:
        '''
      CREATE TABLE $websocketMessages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT NOT NULL,
        session_id TEXT,
        is_sent INTEGER NOT NULL, -- 0 or 1
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY(request_id) REFERENCES nodes(id) ON DELETE CASCADE,
        FOREIGN KEY(session_id) REFERENCES websocket_sessions(id) ON DELETE CASCADE
      )
    ''',
  );

  static List<String> queriesList = [
    queries.collections,
    queries.nodes,
    queries.history,
    queries.environments,
    queries.cookieJars,
    queries.websocketSessions,
    queries.websocketMessages,
  ];
  static List<String> tableNames = [
    collections,
    nodes,
    history,
    environments,
    cookieJars,
    websocketSessions,
    websocketMessages,
  ];

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

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await Tables.createAllTables(db);
        await _ensureDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await Tables.dropAllTables(db);
        await Tables.createAllTables(db);
        await _ensureDefaults(db);
        prefs.clear();
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        // for development only
        await Tables.dropAllTables(db);
        await Tables.createAllTables(db);
        await _ensureDefaults(db);
        prefs.clear();
      },
      onOpen: (db) async {
        // Ensure defaults exist even if DB already exists (for migration)
        await _ensureDefaults(db);
      },
    );
    return db;
  }

  static Future<void> _ensureDefaults(Database db) async {
    // 1. Ensure Default Collection
    final collectionResult = await db.query(
      Tables.collections,
      where: 'id = ?',
      whereArgs: [kDefaultCollection.id],
    );

    if (collectionResult.isEmpty) {
      await db.insert(Tables.collections, kDefaultCollection.toMap());
    }

    // 2. Ensure Default Environment exists for Default Collection
    final envResult = await db.query(
      Tables.environments,
      where: 'collection_id = ?',
      whereArgs: [kDefaultCollection.id],
    );

    // Ensure we have a Global one
    final hasGlobal = envResult.any((e) => (e['is_global'] as int?) == 1);
    if (!hasGlobal) {
      // If we have environments but none are Global, update the first one or create new?
      // Since default env is "Default Environment", let's make it Global or create a separate Global.
      // Usually "Global" is distinct.
      // But for FRESH install, we want "Global" + maybe "Development"?
      // Let's just create "Global" if missing.
      await db.insert(Tables.environments, {
        ...kDefaultEnvironment.toMap(),
        'id': const Uuid().v4(),
        'name': 'Global',
        'is_global': 1,
      });
    }

    // 3. Ensure Default Cookie Jar exists for Default Collection
    final jarResult = await db.query(
      Tables.cookieJars,
      where: 'collection_id = ?',
      whereArgs: [kDefaultCollection.id],
    );

    if (jarResult.isEmpty) {
      await db.insert(Tables.cookieJars, kDefaultCookieJar.toMap());
    }
  }
}

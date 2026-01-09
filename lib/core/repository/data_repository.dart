import 'dart:convert';
import 'package:api_craft/core/database/database_helper.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';
import 'package:api_craft/features/request/models/websocket_session.dart';
import 'package:sqflite/sqflite.dart';

class DataRepository {
  final Future<Database> _db;
  final String collectionId;

  DataRepository(this._db, this.collectionId);

  // --- History ---

  Future<void> addHistoryEntry(RawHttpResponse entry, {int limit = 10}) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(Tables.history, {
        ...entry.toMap(),
        'collection_id': collectionId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Enforce limit
      final rows = await txn.query(
        Tables.history,
        columns: ['id'],
        where: 'request_id = ? AND collection_id = ?',
        whereArgs: [entry.requestId, collectionId],
        orderBy: 'executed_at DESC',
      );

      if (rows.length > limit) {
        final idsToDelete = rows
            .skip(limit)
            .map((r) => r['id'] as String)
            .toList();
        // batch delete
        for (var id in idsToDelete) {
          await txn.delete(Tables.history, where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  Future<List<RawHttpResponse>> getHistory(
    String requestId, {
    int limit = 10,
  }) async {
    final db = await _db;
    final rows = await db.query(
      Tables.history,
      where: 'request_id = ? AND collection_id = ?',
      whereArgs: [requestId, collectionId],
      orderBy: 'executed_at DESC',
      limit: limit,
    );
    return rows.map((e) => RawHttpResponse.fromMap(e)).toList();
  }

  Future<void> deleteCurrHistory(String historyId) async {
    final db = await _db;
    await db.delete(Tables.history, where: 'id = ?', whereArgs: [historyId]);
  }

  Future<void> clearHistory(String requestId) async {
    final db = await _db;
    await db.delete(
      Tables.history,
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }

  Future<void> clearHistoryForCollection() async {
    final db = await _db;
    await db.delete(
      Tables.history,
      where: 'collection_id = ?',
      whereArgs: [collectionId],
    );
  }

  // --- Collection Selection ---

  Future<void> updateCollectionSelection(String? envId, String? jarId) async {
    final db = await _db;
    await db.update(
      Tables.collections,
      {'selected_env_id': envId, 'selected_jar_id': jarId},
      where: 'id = ?',
      whereArgs: [collectionId],
    );
  }

  // --- Cookie Jars ---

  Future<List<CookieJarModel>> getCookieJars() async {
    final db = await _db;
    final rows = await db.query(
      Tables.cookieJars,
      where: 'collection_id = ?',
      whereArgs: [collectionId],
    );
    return rows.map((e) => CookieJarModel.fromMap(e)).toList();
  }

  Future<void> createCookieJar(CookieJarModel jar) async {
    final db = await _db;
    await db.insert(
      Tables.cookieJars,
      jar.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCookieJar(CookieJarModel jar) async {
    final db = await _db;
    await db.update(
      Tables.cookieJars,
      jar.toMap(),
      where: 'id = ?',
      whereArgs: [jar.id],
    );
  }

  Future<void> deleteCookieJar(String id) async {
    final db = await _db;
    await db.delete(Tables.cookieJars, where: 'id = ?', whereArgs: [id]);
  }

  // --- Environments ---

  Future<void> createEnvironment(Environment env) async {
    final db = await _db;
    await db.insert(
      Tables.environments,
      env.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- WebSocket ---

  Future<void> createWebSocketSession(WebSocketSession session) async {
    final db = await _db;
    await db.insert(Tables.websocketSessions, {
      ...session.toMap(),
      'collection_id': collectionId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateWebSocketSession(WebSocketSession session) async {
    final db = await _db;
    await db.update(
      Tables.websocketSessions,
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<List<WebSocketSession>> getWebSocketSessions(String requestId) async {
    final db = await _db;
    final rows = await db.query(
      Tables.websocketSessions,
      where: 'request_id = ? AND collection_id = ?',
      whereArgs: [requestId, collectionId],
      orderBy: 'start_time DESC',
    );
    return rows.map((e) => WebSocketSession.fromMap(e)).toList();
  }

  Future<void> deleteWebSocketSession(String sessionId) async {
    final db = await _db;
    await db.delete(
      Tables.websocketSessions,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> addWebSocketMessage(WebSocketMessage msg) async {
    final db = await _db;
    await db.insert(Tables.websocketMessages, msg.toMap());
  }

  Future<List<WebSocketMessage>> getWebSocketMessages(
    String sessionId, {
    int limit = 100,
  }) async {
    final db = await _db;
    final rows = await db.query(
      Tables.websocketMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((e) => WebSocketMessage.fromMap(e)).toList();
  }

  Future<void> clearWebSocketSessionMessages(String sessionId) async {
    final db = await _db;
    await db.delete(
      Tables.websocketMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> clearWebSocketHistory(String requestId) async {
    final db = await _db;
    await db.delete(
      Tables.websocketSessions,
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }
}

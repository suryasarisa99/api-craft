import 'package:api_craft/core/database/entities/collection_entity.dart';
import 'package:api_craft/core/database/entities/cookie_jar_entity.dart';
import 'package:api_craft/core/database/entities/environment_entity.dart';
import 'package:api_craft/core/database/entities/history_entity.dart';
import 'package:api_craft/core/database/entities/websocket_message_entity.dart';
import 'package:api_craft/core/database/entities/websocket_session_entity.dart';
import 'package:api_craft/core/database/objectbox.dart';
import 'package:api_craft/objectbox.g.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';
import 'package:api_craft/features/request/models/websocket_session.dart';

class DataRepository {
  final Future<ObjectBox> _obxFuture;
  final String collectionId;

  DataRepository(this._obxFuture, this.collectionId);

  // --- Helpers for Async Box Access ---
  Future<Box<HistoryEntity>> get _historyBox async =>
      (await _obxFuture).store.box<HistoryEntity>();
  Future<Box<CollectionEntity>> get _colBox async =>
      (await _obxFuture).store.box<CollectionEntity>();
  Future<Box<CookieJarEntity>> get _jarBox async =>
      (await _obxFuture).store.box<CookieJarEntity>();
  Future<Box<EnvironmentEntity>> get _envBox async =>
      (await _obxFuture).store.box<EnvironmentEntity>();
  Future<Box<WebSocketSessionEntity>> get _wsSessBox async =>
      (await _obxFuture).store.box<WebSocketSessionEntity>();
  Future<Box<WebSocketMessageEntity>> get _wsMsgBox async =>
      (await _obxFuture).store.box<WebSocketMessageEntity>();

  // --- History ---

  Future<void> addHistoryEntry(RawHttpResponse entry, {int limit = 10}) async {
    final box = await _historyBox;
    final entity = HistoryEntity.fromModel(entry, collectionId);

    final qExist = box.query(HistoryEntity_.uid.equals(entity.uid)).build();
    final existing = qExist.findFirst();
    qExist.close();

    if (existing != null) {
      entity.id = existing.id;
    }
    box.put(entity);

    final q = box
        .query(
          HistoryEntity_.requestId.equals(entry.requestId) &
              HistoryEntity_.collectionId.equals(collectionId),
        )
        .order(HistoryEntity_.executeAt, flags: Order.descending)
        .build();

    final all = q.find();
    q.close();

    if (all.length > limit) {
      final toDelete = all.skip(limit).map((e) => e.id).toList();
      box.removeMany(toDelete);
    }
  }

  Future<List<RawHttpResponse>> getHistory(
    String requestId, {
    int limit = 10,
  }) async {
    final box = await _historyBox;
    final q = box
        .query(
          HistoryEntity_.requestId.equals(requestId) &
              HistoryEntity_.collectionId.equals(collectionId),
        )
        .order(HistoryEntity_.executeAt, flags: Order.descending)
        .build();

    q.limit = limit;
    final entities = q.find();
    q.close();
    return entities.map((e) => e.toModel()).toList();
  }

  Future<void> deleteCurrHistory(String historyId) async {
    final box = await _historyBox;
    final q = box.query(HistoryEntity_.uid.equals(historyId)).build();
    q.remove();
    q.close();
  }

  Future<void> clearHistory(String requestId) async {
    final box = await _historyBox;
    final q = box.query(HistoryEntity_.requestId.equals(requestId)).build();
    q.remove();
    q.close();
  }

  Future<void> clearHistoryForCollection() async {
    final box = await _historyBox;
    final q = box
        .query(HistoryEntity_.collectionId.equals(collectionId))
        .build();
    q.remove();
    q.close();
  }

  // --- Collection Selection ---

  Future<void> updateCollectionSelection(String? envId, String? jarId) async {
    final box = await _colBox;
    final q = box.query(CollectionEntity_.uid.equals(collectionId)).build();
    final col = q.findFirst();
    q.close();

    if (col != null) {
      col.selectedEnvId = envId;
      col.selectedJarId = jarId;
      box.put(col);
    }
  }

  // --- Cookie Jars ---

  Future<List<CookieJarModel>> getCookieJars() async {
    final box = await _jarBox;
    final q = box
        .query(CookieJarEntity_.collectionId.equals(collectionId))
        .build();
    final res = q.find();
    q.close();
    return res.map((e) => e.toModel()).toList();
  }

  Future<void> createCookieJar(CookieJarModel jar) async {
    final box = await _jarBox;
    final q = box.query(CookieJarEntity_.uid.equals(jar.id)).build();
    final existing = q.findFirst();
    q.close();

    final entity = CookieJarEntity.fromModel(jar);
    if (existing != null) entity.id = existing.id;
    box.put(entity);
  }

  Future<void> updateCookieJar(CookieJarModel jar) async {
    await createCookieJar(jar);
  }

  Future<void> deleteCookieJar(String id) async {
    final box = await _jarBox;
    final q = box.query(CookieJarEntity_.uid.equals(id)).build();
    q.remove();
    q.close();
  }

  // --- Environments ---

  Future<void> createEnvironment(Environment env) async {
    final box = await _envBox;
    final q = box.query(EnvironmentEntity_.uid.equals(env.id)).build();
    final existing = q.findFirst();
    q.close();

    final entity = EnvironmentEntity.fromModel(env);
    if (existing != null) entity.id = existing.id;
    box.put(entity);
  }

  Future<List<Environment>> getEnvironments() async {
    final box = await _envBox;
    final q = box
        .query(EnvironmentEntity_.collectionId.equals(collectionId))
        .build();
    final res = q.find();
    q.close();
    return res.map((e) => e.toModel()).toList();
  }

  Future<void> deleteEnvironment(String id) async {
    final box = await _envBox;
    final q = box.query(EnvironmentEntity_.uid.equals(id)).build();
    q.remove();
    q.close();
  }

  // --- WebSocket ---

  Future<void> createWebSocketSession(WebSocketSession session) async {
    final box = await _wsSessBox;
    final q = box.query(WebSocketSessionEntity_.uid.equals(session.id)).build();
    final existing = q.findFirst();
    q.close();

    final entity = WebSocketSessionEntity.fromModel(session, collectionId);
    if (existing != null) entity.id = existing.id;
    box.put(entity);
  }

  Future<void> updateWebSocketSession(WebSocketSession session) async {
    await createWebSocketSession(session);
  }

  Future<List<WebSocketSession>> getWebSocketSessions(String requestId) async {
    final box = await _wsSessBox;
    final q = box
        .query(
          WebSocketSessionEntity_.requestId.equals(requestId) &
              WebSocketSessionEntity_.collectionId.equals(collectionId),
        )
        .order(WebSocketSessionEntity_.startTime, flags: Order.descending)
        .build();
    final res = q.find();
    q.close();
    return res.map((e) => e.toModel()).toList();
  }

  Future<void> deleteWebSocketSession(String sessionId) async {
    final box = await _wsSessBox;
    final q = box.query(WebSocketSessionEntity_.uid.equals(sessionId)).build();
    q.remove();
    q.close();

    // Cascade delete messages
    final msgBox = await _wsMsgBox;
    final qMsg = msgBox
        .query(WebSocketMessageEntity_.sessionId.equals(sessionId))
        .build();
    qMsg.remove();
    qMsg.close();
  }

  Future<void> addWebSocketMessage(WebSocketMessage msg) async {
    final box = await _wsMsgBox;
    final entity = WebSocketMessageEntity.fromModel(msg);
    box.put(entity);
  }

  Future<List<WebSocketMessage>> getWebSocketMessages(
    String sessionId, {
    int limit = 100,
  }) async {
    final box = await _wsMsgBox;
    final q = box
        .query(WebSocketMessageEntity_.sessionId.equals(sessionId))
        .order(WebSocketMessageEntity_.timestamp, flags: Order.descending)
        .build();
    q.limit = limit;
    final res = q.find();
    q.close();
    return res.map((e) => e.toModel()).toList();
  }

  Future<void> clearWebSocketSessionMessages(String sessionId) async {
    final box = await _wsMsgBox;
    final q = box
        .query(WebSocketMessageEntity_.sessionId.equals(sessionId))
        .build();
    q.remove();
    q.close();
  }

  Future<void> clearWebSocketHistory(String requestId) async {
    final msgBox = await _wsMsgBox;
    final qMsg = msgBox
        .query(WebSocketMessageEntity_.requestId.equals(requestId))
        .build();
    qMsg.remove();
    qMsg.close();

    final sessBox = await _wsSessBox;
    final qSess = sessBox
        .query(WebSocketSessionEntity_.requestId.equals(requestId))
        .build();
    qSess.remove();
    qSess.close();
  }
}

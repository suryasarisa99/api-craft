import 'package:objectbox/objectbox.dart';
import 'package:api_craft/features/request/models/websocket_session.dart';

@Entity()
class WebSocketSessionEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  @Index()
  String collectionId;

  @Index()
  String requestId;

  String? url;

  @Property(type: PropertyType.date)
  DateTime startTime;

  @Property(type: PropertyType.date)
  DateTime? endTime;

  WebSocketSessionEntity({
    this.id = 0,
    required this.uid,
    required this.collectionId,
    required this.requestId,
    this.url,
    required this.startTime,
    this.endTime,
  });

  factory WebSocketSessionEntity.fromModel(
    WebSocketSession model,
    String collectionId,
  ) {
    return WebSocketSessionEntity(
      uid: model.id,
      collectionId: collectionId,
      requestId: model.requestId,
      url: model.url,
      startTime: model.startTime,
      endTime: model.endTime,
    );
  }

  WebSocketSession toModel() {
    return WebSocketSession(
      id: uid,
      requestId: requestId,
      url: url,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

import 'package:objectbox/objectbox.dart';
import 'package:api_craft/api_client/request/models/websocket_session.dart';

@Entity()
class WebSocketSessionEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  @Index()
  String workspaceId;

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
    required this.workspaceId,
    required this.requestId,
    this.url,
    required this.startTime,
    this.endTime,
  });

  factory WebSocketSessionEntity.fromModel(
    WebSocketSession model,
    String workspaceId,
  ) {
    return WebSocketSessionEntity(
      uid: model.id,
      workspaceId: workspaceId,
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

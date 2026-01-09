import 'package:objectbox/objectbox.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';

@Entity()
class WebSocketMessageEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  @Index()
  String requestId;

  @Index()
  String? sessionId;

  bool isSent;
  String message; // Payload could be large

  @Property(type: PropertyType.date)
  DateTime timestamp;

  WebSocketMessageEntity({
    this.id = 0,
    required this.uid,
    required this.requestId,
    this.sessionId,
    required this.isSent,
    required this.message,
    required this.timestamp,
  });

  factory WebSocketMessageEntity.fromModel(WebSocketMessage model) {
    return WebSocketMessageEntity(
      uid: model.id,
      requestId: model.requestId,
      sessionId: model.sessionId,
      isSent: model.isSent,
      message: model.message,
      timestamp: model.timestamp,
    );
  }

  WebSocketMessage toModel() {
    return WebSocketMessage(
      id: uid,
      requestId: requestId,
      sessionId: sessionId,
      isSent: isSent,
      message: message,
      timestamp: timestamp,
    );
  }
}

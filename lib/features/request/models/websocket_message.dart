class WebSocketMessage {
  final String id;
  final String requestId;
  final String? sessionId;
  final bool isSent;
  final String message;
  final DateTime timestamp;

  WebSocketMessage({
    required this.id,
    required this.requestId,
    this.sessionId,
    required this.isSent,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'request_id': requestId,
      'session_id': sessionId,
      'is_sent': isSent ? 1 : 0,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WebSocketMessage.fromMap(Map<String, dynamic> map) {
    return WebSocketMessage(
      id: map['id'] as String,
      requestId: map['request_id'],
      sessionId: map['session_id'],
      isSent: map['is_sent'] == 1,
      message: map['message'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

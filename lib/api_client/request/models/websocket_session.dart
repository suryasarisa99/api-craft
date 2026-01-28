class WebSocketSession {
  final String id;
  final String requestId;
  final String? url;
  final DateTime startTime;
  final DateTime? endTime;

  WebSocketSession({
    required this.id,
    required this.requestId,
    this.url,
    required this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'request_id': requestId,
      'url': url,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
    };
  }

  factory WebSocketSession.fromMap(Map<String, dynamic> map) {
    return WebSocketSession(
      id: map['id'],
      requestId: map['request_id'],
      url: map['url'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
    );
  }
}

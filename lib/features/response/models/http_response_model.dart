import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A class to hold the parsed raw HTTP response details
class RawHttpResponse {
  final String id;
  final String requestId;
  final int statusCode;
  final String statusMessage;
  final DateTime executeAt;
  final int durationMs;
  final String protocolVersion;
  // final Map<String, String> headers;
  final List<List<String>> headers;
  final Uint8List bodyBytes;
  final String body;
  final String? bodyType;
  final String? errorMessage;
  final List<String> redirectUrls;
  final String? finalUrl;

  RawHttpResponse({
    required this.id,
    required this.statusCode,
    required this.statusMessage,
    required this.protocolVersion,
    required this.headers,
    required this.bodyBytes,
    required this.body,
    this.bodyType,
    required this.executeAt,
    required this.durationMs,
    required this.requestId,

    this.errorMessage,
    this.redirectUrls = const [],
    this.finalUrl,
  });

  factory RawHttpResponse.fromMap(Map<String, dynamic> map) {
    return RawHttpResponse(
      id: map['id'],
      requestId: map['request_id'],
      executeAt: DateTime.fromMillisecondsSinceEpoch(map['executed_at'] as int),
      statusCode: map['status_code'],
      durationMs: map['duration_ms'],
      protocolVersion: map['protocol_version'],
      statusMessage: map['status_message'],
      // headers: Map<String, String>.from(map['headers']),
      // headers: (map['headers'] as List<dynamic>)
      //     .map<List<String>>((e) => List<String>.from(e))
      //     .toList(),
      headers: (jsonDecode(map['headers']) as List<dynamic>).map<List<String>>((
        e,
      ) {
        final list = e as List<dynamic>;
        return [list[0].toString(), list[1].toString()];
      }).toList(),
      bodyBytes: base64.decode(map['body_base64']),
      bodyType: map['body_type'],
      body: map['body'],
      errorMessage: map['error_message'],
      redirectUrls: (map['redirect_urls'] != null)
          ? List<String>.from(jsonDecode(map['redirect_urls']))
          : [],
      finalUrl: map['final_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'request_id': requestId,
      'executed_at': executeAt.millisecondsSinceEpoch,
      'status_code': statusCode,
      'duration_ms': durationMs,
      'protocol_version': protocolVersion,
      'status_message': statusMessage,
      'headers': jsonEncode(headers),
      // 'body_bytes': bodyBytes,
      'body': body,
      'body_type': bodyType,
      'body_base64': base64.encode(bodyBytes),
      'error_message': errorMessage,
      'redirect_urls': jsonEncode(redirectUrls),
      'final_url': finalUrl,
    };
  }
}

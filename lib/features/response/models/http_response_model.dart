import 'dart:convert';

import 'package:flutter/foundation.dart';

class TestResult {
  final String description;
  final String status; // 'passed', 'failed'
  final String? error;

  TestResult({required this.description, required this.status, this.error});

  Map<String, dynamic> toMap() => {
    'description': description,
    'status': status,
    'error': error,
  };

  factory TestResult.fromMap(Map<String, dynamic> map) {
    return TestResult(
      description: map['description'] ?? '',
      status: map['status'] ?? 'unknown',
      error: map['error'],
    );
  }
}

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
  final List<TestResult> testResults;
  final List<TestResult> assertionResults;

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
    this.testResults = const [],
    this.assertionResults = const [],
  });

  RawHttpResponse copyWith({
    String? id,
    String? requestId,
    int? statusCode,
    String? statusMessage,
    String? protocolVersion,
    List<List<String>>? headers,
    Uint8List? bodyBytes,
    String? body,
    String? bodyType,
    DateTime? executeAt,
    int? durationMs,
    String? errorMessage,
    List<String>? redirectUrls,
    String? finalUrl,
    List<TestResult>? testResults,
    List<TestResult>? assertionResults,
  }) {
    return RawHttpResponse(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      headers: headers ?? this.headers,
      bodyBytes: bodyBytes ?? this.bodyBytes,
      body: body ?? this.body,
      bodyType: bodyType ?? this.bodyType,
      executeAt: executeAt ?? this.executeAt,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      redirectUrls: redirectUrls ?? this.redirectUrls,
      finalUrl: finalUrl ?? this.finalUrl,
      testResults: testResults ?? this.testResults,
      assertionResults: assertionResults ?? this.assertionResults,
    );
  }

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
      headers: (map['headers'] as List).map<List<String>>((e) {
        final list = e as List;
        return [list[0].toString(), list[1].toString()];
      }).toList(),
      bodyBytes: base64.decode(map['body_base64']),
      bodyType: map['body_type'],
      body: map['body'],
      errorMessage: map['error_message'],
      redirectUrls: (map['redirect_urls'] != null)
          ? List<String>.from(map['redirect_urls'])
          : [],
      finalUrl: map['final_url'],
      testResults:
          (map['test_results'] as List?)
              ?.map((e) => TestResult.fromMap(e))
              .toList() ??
          [],
      assertionResults:
          (map['assertion_results'] as List?)
              ?.map((e) => TestResult.fromMap(e))
              .toList() ??
          [],
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
      'headers': headers,
      // 'body_bytes': bodyBytes,
      'body': body,
      'body_type': bodyType,
      'body_base64': base64.encode(bodyBytes),
      'error_message': errorMessage,
      'redirect_urls': redirectUrls,
      'final_url': finalUrl,
      'test_results': testResults.map((e) => e.toMap()).toList(),
      'assertion_results': assertionResults.map((e) => e.toMap()).toList(),
    };
  }

  Map<String, dynamic> toJsMap() {
    return {
      'id': id,
      'requestId': requestId,
      'executedAt': executeAt.millisecondsSinceEpoch,
      'status': statusCode,
      'durationMs': durationMs,
      'protocolVersion': protocolVersion,
      'statusMessage': statusMessage,
      'headers': headers,
      'body': body,
      'bodyType': bodyType,
      'errorMessage': errorMessage,
      'redirectUrls': redirectUrls,
      'finalUrl': finalUrl,
      'testResults': testResults.map((e) => e.toMap()).toList(),
      'assertionResults': assertionResults.map((e) => e.toMap()).toList(),
    };
  }
}

import 'dart:convert';

import 'package:api_craft/core/models/cookie_jar_model.dart';
import 'package:api_craft/core/utils/parsers.dart';

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

class RedirectStep {
  final int statusCode;
  final String method;
  final String url;
  final List<List<String>> reqHeaders;
  final List<List<String>> resHeaders;
  final bool hasBody;
  final int durationMs;

  RedirectStep({
    required this.statusCode,
    required this.method,
    required this.url,
    required this.reqHeaders,
    required this.resHeaders,
    required this.hasBody,
    this.durationMs = 0,
  });

  Map<String, dynamic> toMap() => {
    'statusCode': statusCode,
    'method': method,
    'url': url,
    'reqHeaders': reqHeaders,
    'resHeaders': resHeaders,
    'hasBody': hasBody,
    'durationMs': durationMs,
  };

  factory RedirectStep.fromMap(Map<String, dynamic> map) {
    return RedirectStep(
      statusCode: map['statusCode'] ?? 0,
      method: map['method'] ?? '',
      url: map['url'] ?? '',
      reqHeaders:
          (map['reqHeaders'] as List?)?.map<List<String>>((e) {
            final list = e as List;
            return [list[0].toString(), list[1].toString()];
          }).toList() ??
          [],
      resHeaders:
          (map['resHeaders'] as List?)?.map<List<String>>((e) {
            final list = e as List;
            return [list[0].toString(), list[1].toString()];
          }).toList() ??
          [],
      hasBody: map['hasBody'] ?? false,
      durationMs: map['durationMs'] ?? 0,
    );
  }
}

/// A class to hold the parsed raw HTTP response details
class ResponseHistory {
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

  String get body {
    try {
      return utf8.decode(bodyBytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bodyBytes); // Fallback
    }
  }

  final String? bodyType;
  final String? errorMessage;
  final List<RedirectStep> redirects;
  final String? finalUrl;
  final List<TestResult> testResults;
  final List<TestResult> assertionResults;

  final List<List<String>>? reqHeaders;
  final String? reqBody;

  // Derived properties (not stored in DB, parsed from headers)
  late final List<List<String>> reqCookies;
  late final List<CookieDef> resCookies;

  ResponseHistory({
    required this.id,
    required this.statusCode,
    required this.statusMessage,
    required this.protocolVersion,
    required this.headers,
    required this.bodyBytes,
    this.bodyType,
    required this.executeAt,
    required this.durationMs,
    required this.requestId,

    this.errorMessage,
    this.redirects = const [],
    this.finalUrl,
    this.testResults = const [],
    this.assertionResults = const [],
    this.reqHeaders,
    this.reqBody,
  }) {
    if (reqHeaders != null) {
      final cookieHeaders = reqHeaders!
          .where((h) => h[0].toLowerCase() == 'cookie')
          .toList();
      reqCookies = cookieHeaders
          .expand((h) => ParserUtils.parseCookies(h[1]))
          .toList();
    } else {
      reqCookies = [];
    }
    final url = finalUrl;
    if (url != null) {
      resCookies = RawHeaderUtils.getSetCookies(headers, Uri.parse(url));
    }
  }

  ResponseHistory copyWith({
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
    List<RedirectStep>? redirects,
    String? finalUrl,
    List<TestResult>? testResults,
    List<TestResult>? assertionResults,
    List<List<String>>? reqHeaders,
    String? reqBody,
  }) {
    return ResponseHistory(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      headers: headers ?? this.headers,
      bodyBytes: bodyBytes ?? this.bodyBytes,
      bodyType: bodyType ?? this.bodyType,
      executeAt: executeAt ?? this.executeAt,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      redirects: redirects ?? this.redirects,
      finalUrl: finalUrl ?? this.finalUrl,
      testResults: testResults ?? this.testResults,
      assertionResults: assertionResults ?? this.assertionResults,
      reqHeaders: reqHeaders ?? this.reqHeaders,
      reqBody: reqBody ?? this.reqBody,
    );
  }

  factory ResponseHistory.fromMap(Map<String, dynamic> map) {
    return ResponseHistory(
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
      errorMessage: map['error_message'],
      redirects:
          (map['redirects'] as List?)
              ?.map((e) => RedirectStep.fromMap(e))
              .toList() ??
          [],
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
      reqHeaders: (map['req_headers'] as List?)?.map<List<String>>((e) {
        final list = e as List;
        return [list[0].toString(), list[1].toString()];
      }).toList(),
      reqBody: map['req_body'],
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
      'redirects': redirects.map((e) => e.toMap()).toList(),
      'final_url': finalUrl,
      'test_results': testResults.map((e) => e.toMap()).toList(),
      'assertion_results': assertionResults.map((e) => e.toMap()).toList(),
      'req_headers': reqHeaders,
      'req_body': reqBody,
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
      'redirects': redirects.map((e) => e.toMap()).toList(),
      'finalUrl': finalUrl,
      'testResults': testResults.map((e) => e.toMap()).toList(),
      'assertionResults': assertionResults.map((e) => e.toMap()).toList(),
      'reqHeaders': reqHeaders,
      'reqBody': reqBody,
    };
  }

  factory ResponseHistory.dummyRes() {
    return ResponseHistory.fromMap({
      'id': 'dummy',
      'request_id': 'dummy',
      'executed_at': DateTime.now().millisecondsSinceEpoch,
      'status_code': 200,
      'duration_ms': 100,
      'protocol_version': 'HTTP/1.1',
      'status_message': 'OK',
      'headers': [
        ['dummy-header', 'dummy-value'],
      ],
      'body': 'dummy',
      'body_type': 'dummy',
      'body_base64': base64.encode(Uint8List.fromList([])),
      'error_message': 'dummy',
      'redirects': [],
      'final_url': 'dummy',
      'test_results': [
        {'description': 'dummy', 'status': 'dummy', 'error': 'dummy'},
      ],
      'assertion_results': [
        {'description': 'dummy', 'status': 'dummy', 'error': 'dummy'},
      ],
      'req_headers': [
        ['dummy-req-header', 'dummy-req-value'],
      ],
      'req_body': 'dummy-req-body',
    });
  }
}

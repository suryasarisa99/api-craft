import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';
// import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:api_craft/core/models/models.dart'; // Ensure correct export

@Entity()
class HistoryEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  @Index()
  String requestId;

  @Index()
  String workspaceId; // Need this for filtering history by workspace

  int statusCode;
  String statusMessage;

  @Property(type: PropertyType.date)
  DateTime executeAt;

  int durationMs;
  String protocolVersion;

  // Flex Props
  List<dynamic>? headers;

  @Property(type: PropertyType.byteVector)
  Uint8List bodyBytes;

  String? bodyType;
  String? errorMessage;

  // Stored as List<Map<String, dynamic>>
  List<dynamic>? redirects;

  String? finalUrl;

  // Stored as List<Map<String, dynamic>>
  List<dynamic>? testResults;
  List<dynamic>? assertionResults;

  // Request Details
  List<dynamic>? reqHeaders;
  String? reqBody;

  HistoryEntity({
    this.id = 0,
    required this.uid,
    required this.requestId,
    required this.workspaceId,
    required this.statusCode,
    required this.statusMessage,
    required this.executeAt,
    required this.durationMs,
    required this.protocolVersion,
    this.headers,
    required this.bodyBytes,
    this.bodyType,
    this.errorMessage,
    this.redirects,
    this.finalUrl,
    this.testResults,
    this.assertionResults,
    this.reqHeaders,
    this.reqBody,
  });

  factory HistoryEntity.fromModel(ResponseHistory model, String workspaceId) {
    // Model doesn't have workspaceId, inherited from context
    return HistoryEntity(
      uid: model.id,
      requestId: model.requestId,
      workspaceId: workspaceId,
      statusCode: model.statusCode,
      statusMessage: model.statusMessage,
      executeAt: model.executeAt,
      durationMs: model.durationMs,
      protocolVersion: model.protocolVersion,
      headers: model.headers,
      bodyBytes: model.bodyBytes,
      bodyType: model.bodyType,
      errorMessage: model.errorMessage,
      redirects: model.redirects.map((e) => e.toMap()).toList(),
      finalUrl: model.finalUrl,
      testResults: model.testResults.map((e) => e.toMap()).toList(),
      assertionResults: model.assertionResults.map((e) => e.toMap()).toList(),
      reqHeaders: model.reqHeaders,
      reqBody: model.reqBody,
    );
  }

  ResponseHistory toModel() {
    final explicitHeaders = (headers ?? []).map<List<String>>((e) {
      return List<String>.from((e as List).map((s) => s.toString()));
    }).toList();

    final explicitRedirects = (redirects ?? []).map<RedirectStep>((e) {
      return RedirectStep.fromMap(Map<String, dynamic>.from(e));
    }).toList();

    final explicitTests = (testResults ?? []).map<TestResult>((e) {
      return TestResult.fromMap(Map<String, dynamic>.from(e));
    }).toList();

    final explicitAssertions = (assertionResults ?? []).map<TestResult>((e) {
      return TestResult.fromMap(Map<String, dynamic>.from(e));
    }).toList();

    final explicitReqHeaders = (reqHeaders ?? []).map<List<String>>((e) {
      return List<String>.from((e as List).map((s) => s.toString()));
    }).toList();

    return ResponseHistory(
      id: uid,
      requestId: requestId,
      statusCode: statusCode,
      statusMessage: statusMessage,
      executeAt: executeAt,
      durationMs: durationMs,
      protocolVersion: protocolVersion,
      headers: explicitHeaders,
      bodyBytes: bodyBytes,
      // body property is computed getter in model now
      bodyType: bodyType,
      errorMessage: errorMessage,
      redirects: explicitRedirects,
      finalUrl: finalUrl,
      testResults: explicitTests,
      assertionResults: explicitAssertions,
      reqHeaders: explicitReqHeaders,
      reqBody: reqBody,
    );
  }
}

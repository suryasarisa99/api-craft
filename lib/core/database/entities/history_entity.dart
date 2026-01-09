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
  String collectionId; // Need this for filtering history by collection

  int statusCode;
  String statusMessage;

  @Property(type: PropertyType.date)
  DateTime executeAt;

  int durationMs;
  String protocolVersion;

  // Flex Props
  // Headers is List<List<String>> in model.
  // ObjectBox Flex supports List<dynamic>.
  // We can store it as List<dynamic> where each item is List<String>.
  List<dynamic>? headers;

  @Property(type: PropertyType.byteVector)
  Uint8List bodyBytes;

  String body;
  String? bodyType;
  String? errorMessage;

  // Flex
  List<String>? redirectUrls;

  String? finalUrl;

  HistoryEntity({
    this.id = 0,
    required this.uid,
    required this.requestId,
    required this.collectionId,
    required this.statusCode,
    required this.statusMessage,
    required this.executeAt,
    required this.durationMs,
    required this.protocolVersion,
    this.headers,
    required this.bodyBytes,
    required this.body,
    this.bodyType,
    this.errorMessage,
    this.redirectUrls,
    this.finalUrl,
  });

  factory HistoryEntity.fromModel(RawHttpResponse model, String collectionId) {
    // Model doesn't have collectionId, inherited from context
    return HistoryEntity(
      uid: model.id,
      requestId: model.requestId,
      collectionId: collectionId,
      statusCode: model.statusCode,
      statusMessage: model.statusMessage,
      executeAt: model.executeAt,
      durationMs: model.durationMs,
      protocolVersion: model.protocolVersion,
      headers: model.headers, // stored as Isar/ObjectBox List<dynamic>
      bodyBytes: model.bodyBytes,
      body: model.body,
      bodyType: model.bodyType,
      errorMessage: model.errorMessage,
      redirectUrls: model.redirectUrls,
      finalUrl: model.finalUrl,
    );
  }

  RawHttpResponse toModel() {
    // Convert List<dynamic> -> List<List<String>>
    final List<List<String>> explicitHeaders = (headers ?? []).map((e) {
      if (e is List) {
        return e.map((s) => s.toString()).toList();
      }
      return <String>[];
    }).toList();

    return RawHttpResponse(
      id: uid,
      requestId: requestId,
      statusCode: statusCode,
      statusMessage: statusMessage,
      protocolVersion: protocolVersion,
      headers: explicitHeaders,
      bodyBytes: bodyBytes,
      body: body,
      bodyType: bodyType,
      executeAt: executeAt,
      durationMs: durationMs,
      errorMessage: errorMessage,
      redirectUrls: redirectUrls ?? [],
      finalUrl: finalUrl,
    );
  }
}

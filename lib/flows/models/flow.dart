import 'package:api_craft/core/models/models.dart';
import 'package:collection/collection.dart';
import 'package:mockhttp/types.dart';
import 'package:mockhttp/types/ongoing.dart';
import 'package:nanoid/non_secure.dart';

class HttpFlow {
  final String id;
  final String state;
  final bool reqEdited;
  final bool resEdited;
  final FlowRequest? request;
  final FlowRequest? requestBackup;
  final FlowResponse? response;
  final FlowResponse? responseBackup;

  HttpFlow({
    required this.id,
    this.state = "",
    this.reqEdited = false,
    this.resEdited = false,
    this.request,
    this.response,
    this.requestBackup,
    this.responseBackup,
  });

  // copy with
  HttpFlow copyWith({
    String? id,
    String? state,
    FlowRequest? request,
    bool? reqEdited,
    bool? resEdited,
    FlowResponse? response,
    FlowRequest? requestBackup,
    FlowResponse? responseBackup,
  }) {
    return HttpFlow(
      id: id ?? this.id,
      reqEdited: reqEdited ?? this.reqEdited,
      resEdited: resEdited ?? this.resEdited,
      state: state ?? this.state,
      request: request ?? this.request,
      response: response ?? this.response,
      requestBackup: requestBackup ?? this.requestBackup,
      responseBackup: responseBackup ?? this.responseBackup,
    );
  }

  HttpFlow updateReq(FlowRequest req) {
    return copyWith(request: req);
  }

  HttpFlow updateRes(FlowResponse res) {
    return copyWith(response: res);
  }

  HttpFlow editReq(FlowRequest req) {
    if (!reqEdited) {
      return copyWith(reqEdited: true, requestBackup: request, request: req);
    }
    return copyWith(request: req);
  }

  HttpFlow editRes(FlowResponse res) {
    if (!resEdited) {
      return copyWith(resEdited: true, responseBackup: response, response: res);
    }
    return copyWith(response: res);
  }

  HttpFlow reset() {
    return copyWith(
      reqEdited: false,
      resEdited: false,
      request: requestBackup,
      response: responseBackup,
      requestBackup: null,
      responseBackup: null,
    );
  }

  HttpFlow duplicate() {
    final id = nanoid();
    return HttpFlow(
      id: id,
      reqEdited: reqEdited,
      resEdited: resEdited,
      state: state,
      request: request?.copyWith(id: id),
      response: response?.copyWith(id: id),
      requestBackup: requestBackup?.copyWith(id: id),
      responseBackup: responseBackup?.copyWith(id: id),
    );
  }

  static String? getHeader(List<List<String>> headers, String headerName) {
    final key = headerName.toLowerCase();
    return headers.firstWhere((h) => h.first.toLowerCase() == key).last;
  }
}

List<KeyValueItem> _fromList(List<List<String>> headers) {
  return headers
      .mapIndexed(
        (i, e) => KeyValueItem(id: i.toString(), key: e.first, value: e.last),
      )
      .toList();
}

List<List<String>> _toList(List<KeyValueItem> headers) {
  return headers
      .where((e) => e.isEnabled)
      .map((e) => [e.key, e.value])
      .toList();
}

class FlowRequest {
  final String id;
  final String url;
  final String path;
  final String httpVersion;
  final String method;
  final Destination destination;
  final List<KeyValueItem> headers;
  final OngoingBody body;
  final TimingEvents timingEvents;
  final String? ipAddress;
  final int? contentLen;
  final int? port;
  final String protocol;

  FlowRequest({
    required this.id,
    required this.url,
    required this.method,
    required this.path,
    required this.httpVersion,
    required this.headers,
    required this.protocol,
    required this.timingEvents,
    required this.destination,
    this.contentLen,
    required this.body,
    this.ipAddress,
    this.port,
  });

  factory FlowRequest.fromOngoingReq(OngoingRequest r) {
    return FlowRequest(
      id: r.id,
      url: r.url,
      method: r.method,
      path: r.path,
      contentLen: r.contentLength,
      ipAddress: r.remoteIpAddress,
      port: r.remotePort,
      httpVersion: r.httpVersion,
      destination: r.destination,
      headers: _fromList(r.headers),
      body: r.body,
      protocol: r.protocol,
      timingEvents: r.timingEvents,
    );
  }

  Future<MutableRequest> toMutableReq() async {
    return MutableRequest(
      id: id,
      url: url,
      method: method,
      path: path,
      remoteIpAddress: ipAddress,
      remotePort: port,
      httpVersion: httpVersion,
      destination: destination,
      headers: _toList(headers),
      tags: [],
      //body: Uint8List
      body: await body.asBuffer(),
      protocol: protocol,
      timingEvents: timingEvents,
    );
  }

  //copy with
  FlowRequest copyWith({
    String? id,
    String? url,
    String? path,
    String? httpVersion,
    String? method,
    List<KeyValueItem>? headers,
    OngoingBody? body,
    TimingEvents? timingEvents,
    String? ipAddress,
    int? contentLen,
    int? port,
    String? protocol,
    Destination? destination,
  }) {
    return FlowRequest(
      id: id ?? this.id,
      url: url ?? this.url,
      path: path ?? this.path,
      httpVersion: httpVersion ?? this.httpVersion,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      destination: destination ?? this.destination,
      body: body ?? this.body,
      timingEvents: timingEvents ?? this.timingEvents,
      ipAddress: ipAddress ?? this.ipAddress,
      contentLen: contentLen ?? this.contentLen,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
    );
  }

  Map<String, dynamic> toJsMap() {
    return {
      'id': id,
      'url': url,
      'method': method,
      'path': path, // Not always present in headers?
      'headers': Map.fromEntries(headers.map((e) => MapEntry(e.key, e.value))),
      // Body handling might be complex, simplified for now
      'body': null, // Async body not tailored for sync JS check yet
    };
  }
}

class FlowResponse {
  final String id;
  final List<KeyValueItem> headers;
  final CompletedBody? body;
  final int statusCode;
  final TimingEvents timingEvents;
  final String? contentType;
  final int? contentLen;

  FlowResponse({
    required this.id,
    required this.headers,
    required this.contentLen,
    required this.statusCode,
    required this.timingEvents,
    this.contentType,
    this.body,
  });

  factory FlowResponse.fromOngoingRes(OngoingResponse r) {
    return FlowResponse(
      id: r.id,
      contentLen: null,
      headers: _fromList(r.getHeaders()),
      // body: r.body,
      statusCode: r.statusCode,
      contentType: HttpFlow.getHeader(r.getHeaders(), 'content-type'),
      timingEvents: r.timingEvents,
    );
  }
  factory FlowResponse.fromCompletedRes(CompletedResponse r) {
    return FlowResponse(
      id: r.id,
      contentLen: r.contentLength,
      body: r.body,
      headers: _fromList(r.headers),
      statusCode: r.statusCode,
      contentType: HttpFlow.getHeader(r.headers, 'content-type'),
      timingEvents: r.timingEvents,
    );
  }

  //copy with
  FlowResponse copyWith({
    String? id,
    List<KeyValueItem>? headers,
    CompletedBody? body,
    int? contentLen,
    int? statusCode,
    String? contentType,
    TimingEvents? timingEvents,
  }) {
    return FlowResponse(
      id: id ?? this.id,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      contentLen: contentLen ?? this.contentLen,
      statusCode: statusCode ?? this.statusCode,
      contentType: contentType ?? this.contentType,
      timingEvents: timingEvents ?? this.timingEvents,
    );
  }

  Future<MutableResponse> toMutableRes() async {
    return MutableResponse(
      id: id,
      headers: _toList(headers),
      body: body?.buffer,
      statusCode: statusCode,
      timingEvents: timingEvents,
      statusMessage: 'Ok',
      tags: [],
    );
  }

  Map<String, dynamic> toJsMap() {
    return {
      'id': id,
      'statusCode': statusCode,
      'headers': Map.fromEntries(headers.map((e) => MapEntry(e.key, e.value))),
      // Body handling
      'body': body?.toString(), // Potentially unsafe/partial
    };
  }
}

import 'package:mockhttp/types.dart';
import 'package:mockhttp/types/ongoing.dart';

class HttpFlow {
  final String id;
  final String state;
  final bool reqEdited;
  final bool resEdited;
  final FlowRequest? request;
  final FlowResponse? response;

  HttpFlow({
    required this.id,
    this.state = "",
    this.reqEdited = false,
    this.resEdited = false,
    this.request,
    this.response,
  });

  // copy with
  HttpFlow copyWith({
    String? id,
    String? state,
    FlowRequest? request,
    bool? reqEdited,
    bool? resEdited,
    FlowResponse? response,
  }) {
    return HttpFlow(
      id: id ?? this.id,
      reqEdited: reqEdited ?? this.reqEdited,
      resEdited: resEdited ?? this.resEdited,
      state: state ?? this.state,
      request: request ?? this.request,
      response: response ?? this.response,
    );
  }

  HttpFlow updateReq(FlowRequest req) {
    return copyWith(request: req);
  }

  HttpFlow updateRes(FlowResponse res) {
    return copyWith(response: res);
  }

  static String? getHeader(List<List<String>> headers, String headerName) {
    final key = headerName.toLowerCase();
    return headers.firstWhere((h) => h.first.toLowerCase() == key).last;
  }
}

class FlowRequest {
  final String id;
  final String url;
  final String path;
  final String httpVersion;
  final String method;
  final List<List<String>> headers;
  final OngoingBody? body;
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
    this.contentLen,
    this.body,
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
      headers: r.headers,
      body: r.body,
      protocol: r.protocol,
      timingEvents: r.timingEvents,
    );
  }
}

class FlowResponse {
  final String id;
  final List<List<String>> headers;
  final OngoingBody? body;
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
      headers: r.getHeaders(),
      body: r.body,
      statusCode: r.statusCode,
      contentType: HttpFlow.getHeader(r.getHeaders(), 'content-type'),
      timingEvents: r.timingEvents,
    );
  }
  factory FlowResponse.fromCompletedRes(CompletedResponse r) {
    return FlowResponse(
      id: r.id,
      contentLen: r.contentLength,
      headers: r.headers,
      statusCode: r.statusCode,
      contentType: HttpFlow.getHeader(r.headers, 'content-type'),
      timingEvents: r.timingEvents,
    );
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';

final httpEngine = HttpEngine(
  proxy: "127.0.0.1:8080", // Set to null to disable proxy
);

class HttpEngine {
  late final Dio dio;

  HttpEngine({String? proxy}) {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        followRedirects: false,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();

      if (proxy != null) {
        client.findProxy = (_) => "PROXY $proxy";
      }

      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

      return client;
    };

    dio.httpClientAdapter = adapter;
    dio.interceptors.add(FullLogger());
  }

  // <<< SIMPLE API CLIENT METHOD HERE >>>
  Future<Response> send({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? query,
    dynamic body,
  }) async {
    return await dio.request(
      url,
      data: body,
      queryParameters: query,
      options: Options(method: method, headers: headers),
    );
  }
}

class FullLogger extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint("=== REQUEST ===========================");
    debugPrint("${options.method} ${options.uri}");
    debugPrint("Headers:");
    options.headers.forEach((k, v) => debugPrint("$k: $v"));

    if (options.data != null) {
      debugPrint("Body:");
      debugPrint(options.data);
    }

    debugPrint("=======================================");
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint("=== RESPONSE ==========================");
    debugPrint("Status: ${response.statusCode}");
    debugPrint("URL: ${response.requestOptions.uri}");

    debugPrint("Headers:");
    response.headers.forEach((k, v) => debugPrint("$k: $v"));

    debugPrint("Body:");
    try {
      debugPrint(String.fromCharCodes(response.data));
    } catch (_) {
      debugPrint("[non-text body: ${response.data.length} bytes]");
    }

    debugPrint("=======================================");
    handler.next(response);
  }

  @override
  void onError(DioException e, ErrorInterceptorHandler handler) {
    debugPrint("=== ERROR =============================");
    // debugPrint(e);
    debugPrint("=======================================");
    handler.next(e);
  }
}

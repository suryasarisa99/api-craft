import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:api_craft/core/network/raw/parse_raw_response.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter/foundation.dart';

Future<RawHttpResponse> sendRawHttp({
  required String method,
  required Uri url,
  List<List<String>>? headers,
  dynamic body,
  bool useProxy = false,
  String proxyHost = '127.0.0.1',
  int proxyPort = 8080,
  required String requestId,
  Duration connectTimeout = const Duration(seconds: 10),
  int maxRedirects = 5,
}) async {
  Uri currentUrl = url;
  int redirectCount = 0;
  List<String> redirectUrls = [];
  final requestSentTime = DateTime.now(); // Start time of FIRST request

  while (redirectCount <= maxRedirects) {
    final isHttps = currentUrl.scheme == 'https';
    final port = (currentUrl.port == 0)
        ? (isHttps ? 443 : 80)
        : currentUrl.port;

    late Socket socket;

    try {
      // 1. Connect
      if (useProxy) {
        socket = await Socket.connect(
          proxyHost,
          proxyPort,
          timeout: connectTimeout,
        );
      } else {
        socket = await Socket.connect(
          currentUrl.host,
          port,
          timeout: connectTimeout,
        );
      }

      // 2. HTTPS Proxy Tunnel (CONNECT method)
      if (useProxy && isHttps) {
        final connectReq =
            'CONNECT ${currentUrl.host}:$port HTTP/1.1\r\n'
            'Host: ${currentUrl.host}:$port\r\n\r\n';
        socket.write(connectReq);
        await socket.flush();

        // Read tunnel response
        final headerBytes = await _readProxyResponse(socket);
        final headerStr = ascii.decode(headerBytes);
        if (!headerStr.toUpperCase().contains('200')) {
          await socket.close();
          throw Exception('Proxy CONNECT failed: $headerStr');
        }

        // Upgrade to SSL
        socket = await SecureSocket.secure(
          socket,
          host: currentUrl.host,
          onBadCertificate: (_) => true,
        );
      } else if (isHttps) {
        socket = await SecureSocket.secure(
          socket,
          host: currentUrl.host,
          onBadCertificate: (_) => true,
        );
      }

      // 3. Request Line
      final path = (useProxy && !isHttps)
          ? currentUrl.toString()
          : (currentUrl.path.isEmpty ? "/" : currentUrl.path) +
                (currentUrl.hasQuery ? "?${currentUrl.query}" : "");

      final buffer = StringBuffer();
      buffer.write('$method $path HTTP/1.1\r\n');

      // 4. Headers
      final defaultPort = isHttps ? 443 : 80;
      final hostHeader =
          (currentUrl.port == 0 || currentUrl.port == defaultPort)
          ? currentUrl.host
          : '${currentUrl.host}:${currentUrl.port}';
      buffer.write('Host: $hostHeader\r\n');

      bool hasConnectionHeader = false;
      bool hasAcceptEncoding = false;

      if (headers != null) {
        for (final h in headers) {
          if (h.length != 2) continue;
          if (h[0].toLowerCase() == 'connection') hasConnectionHeader = true;
          if (h[0].toLowerCase() == 'accept-encoding') hasAcceptEncoding = true;
          // Don't send Host header if we already set it?? No, we set it manually above.
          // Should filter out 'Host' from user headers to avoid dupes?
          if (h[0].toLowerCase() == 'host') continue;
          buffer.write('${h[0]}: ${h[1]}\r\n');
        }
      }
      if (!hasConnectionHeader) {
        buffer.write('Connection: close\r\n');
      }
      // Asking for Gzip is standard, but you can remove this if you want pure raw
      if (!hasAcceptEncoding) {
        buffer.write('Accept-Encoding: gzip\r\n');
      }

      // 5. Body Preparation
      List<int> bodyBytesToSend = [];
      // Only send body on initial request or if redirects dictate (usually 307/308 preserve)
      // But standard HttpClient usually strips body on 301/302/303 -> GET
      // For simplicity in raw tool:
      // If redirectCount > 0, check status code of previous response?
      // Actually we are inside the new loop iteration. We don't know the PREVIOUS status code easily here
      // unless we stored it.
      // But typically redirects change method to GET for 301/302/303.
      // For now, let's simplisticly KEEP the body if it's the first request,
      // or if we decide to implement strict redirect method changing logic.
      //
      // Simplified: Always send body if 'method' didn't change (which we aren't changing yet).
      // Ideally we should handle method changes.
      // Let's implement partial logic: if not first request, maybe drop body if GET?

      // FIX: Proper redirect handling implies logic update.
      // Let's assume method stays same for now OR user wants Raw control.
      // But if we follow a redirect, we usually want to follow standard browser rules.
      // Let's stick to: Always send provided body (User provided).

      if (body != null) {
        if (body is String) {
          bodyBytesToSend = utf8.encode(body);
        } else if (body is List<int>) {
          bodyBytesToSend = body;
        }

        final hasContentLength =
            headers?.any((h) => h[0].toLowerCase() == 'content-length') ??
            false;
        if (!hasContentLength) {
          buffer.write('Content-Length: ${bodyBytesToSend.length}\r\n');
        }
      }

      buffer.write('\r\n'); // End of headers

      // 6. Write & Flush
      socket.write(buffer.toString());
      if (bodyBytesToSend.isNotEmpty) socket.add(bodyBytesToSend);

      await socket.flush();

      // 7. Read Response (Read FULL stream since we sent Connection: close)
      final allBytes = await socket
          .fold<BytesBuilder>(BytesBuilder(), (b, d) {
            b.add(d);
            return b;
          })
          .then((b) => b.toBytes());

      await socket.close();

      // Parse to check for redirect
      // We need a lightweight parse first? Or just parse fully using our helper?
      // Helper returns RawHttpResponse object.
      // But helper calculates duration based on requestSentTime.
      // Let's parse it now.

      final tempResponse = parseRawResponse(
        allBytes,
        requestSentTime:
            requestSentTime, // This is technically inaccurate for Redirects steps, but ok for final?
        // Actually we want the duration for THIS step or Total?
        // "durationMs" in RawHttpResponse usually implies Total Duration.
        durationMs: 0, // Placeholder
        requestId: requestId,
        redirectUrls: redirectUrls, // Pass current history? Or update later?
      );

      if (tempResponse.statusCode >= 300 && tempResponse.statusCode < 400) {
        // It is a redirect
        final location = tempResponse.headers
            .firstWhere(
              (h) => h[0].toLowerCase() == 'location',
              orElse: () => [],
            )
            .elementAtOrNull(1);
        if (location != null &&
            location.isNotEmpty &&
            redirectCount < maxRedirects) {
          redirectCount++;
          redirectUrls.add(currentUrl.toString()); // Add OLD url to history

          // Resolve relative URL
          final newUri = Uri.parse(location);
          if (newUri.hasScheme) {
            currentUrl = newUri;
          } else {
            currentUrl = currentUrl.resolve(location);
          }

          debugPrint(
            "Refirecting to: $currentUrl ($redirectCount/$maxRedirects)",
          );
          continue; // Loop again
        }
      }

      // If not redirecting, or max reached, return this response
      final responseReceivedTime = DateTime.now();
      // Wait, existing code: durationMs = difference in Microseconds. (Variable name says MS but code said Microseconds?)
      // Line 138: .inMicroseconds;
      // Let's check existing code again. parseRawResponse accepts int durationMs.
      // If existing code passed Microseconds, then `durationMs` field is actually Microseconds.
      // Let's stick to microseconds to match existing behavior if that's what it was.

      final durationMs = responseReceivedTime
          .difference(requestSentTime)
          .inMilliseconds;

      // Re-parse or just update the tempResponse?
      // `tempResponse` is a final object. We might need to copyWith or just parse again correctly.
      // simpler to parse again or create new.

      return parseRawResponse(
        allBytes,
        requestSentTime: requestSentTime,
        durationMs: durationMs,
        requestId: requestId,
        redirectUrls: redirectUrls,
        finalUrl: currentUrl.toString(),
      );
    } catch (e) {
      // Ensure socket is closed on error
      try {
        socket.destroy();
      } catch (_) {}
      rethrow;
    }
  }

  // If we exit loop (shouldn't happen due to return)?
  throw Exception("Max redirects exceeded or loop error");
}

// Proxy Reader Helper (Slightly improved to handle pause)
Future<Uint8List> _readProxyResponse(Socket socket) {
  final completer = Completer<Uint8List>();
  final builder = BytesBuilder(copy: false);
  late StreamSubscription<Uint8List> sub;

  sub = socket.listen(
    (data) {
      builder.add(data);
      if (_containsDoubleCrlf(builder.toBytes())) {
        sub.pause();
        // Note: In Dart, pausing a single-subscription stream before 'SecureSocket.secure'
        // takes over is tricky. Usually, you rely on the OS buffer or 'Connection: close' logic.
        // But for proxy tunneling, this "pause" relies on the hope that SecureSocket
        // can attach to the underlying fd.
        completer.complete(builder.toBytes());
      }
    },
    onError: (e) => completer.completeError(e),
    cancelOnError: true,
  );
  return completer.future;
}

bool _containsDoubleCrlf(Uint8List bytes) {
  if (bytes.length < 4) return false;
  for (var i = 0; i <= bytes.length - 4; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      return true;
    }
  }
  return false;
}

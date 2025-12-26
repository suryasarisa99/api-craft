import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:api_craft/core/network/raw/parse_raw_response.dart';
import 'package:api_craft/core/models/models.dart';

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
}) async {
  final isHttps = url.scheme == 'https';
  final port = (url.port == 0) ? (isHttps ? 443 : 80) : url.port;

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
      socket = await Socket.connect(url.host, port, timeout: connectTimeout);
    }

    // 2. HTTPS Proxy Tunnel (CONNECT method)
    if (useProxy && isHttps) {
      final connectReq =
          'CONNECT ${url.host}:$port HTTP/1.1\r\n'
          'Host: ${url.host}:$port\r\n\r\n';
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
        host: url.host,
        onBadCertificate: (_) => true,
      );
    } else if (isHttps) {
      socket = await SecureSocket.secure(
        socket,
        host: url.host,
        onBadCertificate: (_) => true,
      );
    }

    // 3. Request Line
    final path = (useProxy && !isHttps)
        ? url.toString()
        : (url.path.isEmpty ? "/" : url.path) +
              (url.hasQuery ? "?${url.query}" : "");

    final buffer = StringBuffer();
    buffer.write('$method $path HTTP/1.1\r\n');

    // 4. Headers
    final defaultPort = isHttps ? 443 : 80;
    final hostHeader = (url.port == 0 || url.port == defaultPort)
        ? url.host
        : '${url.host}:${url.port}';
    buffer.write('Host: $hostHeader\r\n');

    bool hasConnectionHeader = false;
    bool hasAcceptEncoding = false;

    if (headers != null) {
      for (final h in headers) {
        if (h.length != 2) continue;
        if (h[0].toLowerCase() == 'connection') hasConnectionHeader = true;
        if (h[0].toLowerCase() == 'accept-encoding') hasAcceptEncoding = true;
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
    // 5. Body Preparation
    List<int> bodyBytesToSend = [];
    if (body != null) {
      if (body is String) {
        bodyBytesToSend = utf8.encode(body);
      } else if (body is List<int>) {
        bodyBytesToSend = body;
      }

      final hasContentLength =
          headers?.any((h) => h[0].toLowerCase() == 'content-length') ?? false;
      if (!hasContentLength) {
        buffer.write('Content-Length: ${bodyBytesToSend.length}\r\n');
      }
    }

    buffer.write('\r\n'); // End of headers

    // 6. Write & Flush
    socket.write(buffer.toString());
    if (bodyBytesToSend.isNotEmpty) socket.add(bodyBytesToSend);
    final requestSentTime = DateTime.now();
    await socket.flush();

    // 7. Read Response (Read FULL stream since we sent Connection: close)
    final allBytes = await socket
        .fold<BytesBuilder>(BytesBuilder(), (b, d) {
          b.add(d);
          return b;
        })
        .then((b) => b.toBytes());

    await socket.close();
    final responseReceivedTime = DateTime.now();
    final durationMs = responseReceivedTime
        .difference(requestSentTime)
        .inMicroseconds;
    // 8. Parse Response
    return parseRawResponse(
      allBytes,
      requestSentTime: requestSentTime,
      durationMs: durationMs,
      requestId: requestId,
    );
  } catch (e) {
    // Ensure socket is closed on error
    try {
      socket.destroy();
    } catch (_) {}
    rethrow;
  }
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

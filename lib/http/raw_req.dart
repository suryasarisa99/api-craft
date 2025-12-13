import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

Future<String> sendRawHttp({
  required String method,
  required Uri url,
  List<List<String>>? headers,
  dynamic body,
  bool useProxy = false,
  String proxyHost = '127.0.0.1',
  int proxyPort = 8080,
  Duration connectTimeout = const Duration(seconds: 10),
}) async {
  final isHttps = url.scheme == 'https';
  final port = (url.port == 0) ? (isHttps ? 443 : 80) : url.port;

  Socket socket;

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
  // Proxy HTTP (non-SSL) needs full URL, otherwise just path
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

  // IMPORTANT: Tell server to close socket after response so we don't hang
  // We check if you already added it to avoid duplicates
  bool hasConnectionHeader = false;
  if (headers != null) {
    for (final h in headers) {
      if (h.length != 2) continue;
      if (h[0].toLowerCase() == 'connection') hasConnectionHeader = true;
      buffer.write('${h[0]}: ${h[1]}\r\n');
    }
  }
  if (!hasConnectionHeader) {
    buffer.write('Connection: close\r\n');
  }

  // 5. Body
  List<int> bodyBytes = [];
  if (body != null) {
    if (body is String)
      bodyBytes = utf8.encode(body);
    else if (body is List<int>)
      bodyBytes = body;
    buffer.write('Content-Length: ${bodyBytes.length}\r\n');
  }

  buffer.write('\r\n'); // End of headers

  // 6. Write & Flush
  socket.write(buffer.toString());
  if (bodyBytes.isNotEmpty) socket.add(bodyBytes);
  await socket.flush();

  // 7. Read Response
  // Because we sent 'Connection: close', the server will close the socket
  // immediately after the body, causing this fold to complete instantly.
  final responseBytes = await socket.fold<List<int>>([], (prev, elem) {
    prev.addAll(elem);
    return prev;
  });

  await socket.close();
  return utf8.decode(responseBytes, allowMalformed: true);
}

// Reuse the helper from previous answer
Future<Uint8List> _readProxyResponse(Socket socket) {
  final completer = Completer<Uint8List>();
  final builder = BytesBuilder(copy: false);
  late StreamSubscription<Uint8List> sub;

  sub = socket.listen(
    (data) {
      builder.add(data);
      if (_containsDoubleCrlf(builder.toBytes())) {
        sub.pause(); // Important: Pause, don't cancel!
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
        bytes[i + 3] == 10)
      return true;
  }
  return false;
}

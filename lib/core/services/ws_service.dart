import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:api_craft/core/models/models.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // Manual connection with duplicate header support
  Future<void> manualConnect({
    required ResolvedRequestContext requestContext,
    String? proxyHost,
    int? proxyPort,
  }) async {
    final uri = requestContext.uri;
    final isSecure = uri.scheme == 'wss' || uri.scheme == 'https';
    final port = uri.port != 0 ? uri.port : (isSecure ? 443 : 80);

    Socket socket;
    try {
      if (proxyHost != null && proxyPort != null) {
        // 1. Connect to Proxy
        socket = await Socket.connect(
          proxyHost,
          proxyPort,
          timeout: const Duration(seconds: 10),
        );

        // 2. Perform Proxy Tunneling Handshake (CONNECT)
        socket = await _performProxyHandshake(socket, uri.host, port);
      } else {
        // Direct Connection
        socket = await Socket.connect(
          uri.host,
          port,
          timeout: const Duration(seconds: 10),
        );
      }

      // 3. Secure Upgrade (if needed)
      if (isSecure) {
        socket = await SecureSocket.secure(
          socket,
          host: uri.host,
          onBadCertificate: (_) => true,
        );
      }
    } catch (e) {
      throw Exception("Connection failed: $e");
    }

    // 4. WebSocket Handshake
    try {
      final key = base64.encode(
        List<int>.generate(16, (_) => Random().nextInt(256)),
      );

      // Send WebSocket Upgrade Request
      _sendWsHandshakeRequest(socket, uri, key, requestContext);

      // Wait for Upgraded Socket (Response Intercepted)
      final wrappedSocket = await _performWsHandshakeResponse(socket);

      // 5. Create WebSocket
      final ws = WebSocket.fromUpgradedSocket(wrappedSocket, serverSide: false);

      _channel = IOWebSocketChannel(ws);
    } catch (e) {
      _subscription?.cancel(); // cleanup if handshake fails
      socket.destroy(); // ensure underlying socket is closed
      rethrow;
    }
  }

  Future<Socket> _performProxyHandshake(
    Socket socket,
    String targetHost,
    int targetPort,
  ) async {
    final connectReq =
        'CONNECT $targetHost:$targetPort HTTP/1.1\r\n'
        'Host: $targetHost:$targetPort\r\n\r\n';
    socket.write(connectReq);
    await socket.flush();

    final controller = StreamController<Uint8List>();
    final completer = Completer<void>();
    final buffer = BytesBuilder();
    bool finished = false;

    // Listen to the raw socket to intercept the proxy's CONNECT response
    socket.listen(
      (data) {
        if (finished) {
          controller.add(data); // Pass through remaining data
          return;
        }

        buffer.add(data);
        final bytes = buffer.toBytes();
        final doubleCrlf = _findDoubleCrlf(bytes);

        if (doubleCrlf != -1) {
          finished = true;
          // Verify 200 OK
          final headerBytes = bytes.sublist(0, doubleCrlf + 4);
          final headerStr = utf8.decode(headerBytes);

          if (!headerStr.toUpperCase().contains(' 200 ')) {
            if (!completer.isCompleted) {
              completer.completeError(
                Exception("Proxy Tunnel Failed: $headerStr"),
              );
            }
            return;
          }

          // Push any remaining bytes after the headers to the controller
          if (bytes.length > doubleCrlf + 4) {
            controller.add(bytes.sublist(doubleCrlf + 4));
          }
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
        controller.addError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception("Socket closed during proxy handshake"),
          );
        }
        controller.close();
      },
    );

    await completer.future; // Wait for the proxy handshake to complete
    return _SocketWrapper(socket, controller.stream);
  }

  void _sendWsHandshakeRequest(
    Socket socket,
    Uri uri,
    String key,
    ResolvedRequestContext context,
  ) {
    final buffer = StringBuffer();
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
    final port = uri.port != 0
        ? uri.port
        : (uri.scheme.startsWith('wss') ? 443 : 80);

    buffer.write('GET $path$query HTTP/1.1\r\n');
    buffer.write('Host: ${uri.host}:$port\r\n');
    buffer.write('Upgrade: websocket\r\n');
    buffer.write('Connection: Upgrade\r\n');
    buffer.write('Sec-WebSocket-Key: $key\r\n');
    buffer.write('Sec-WebSocket-Version: 13\r\n');

    for (final h in context.headers) {
      if (h.length == 2) {
        final k = h[0].toLowerCase();
        if ([
          'upgrade',
          'connection',
          'sec-websocket-key',
          'sec-websocket-version',
          'host',
        ].contains(k)) {
          continue;
        }
        buffer.write('${h[0]}: ${h[1]}\r\n');
      }
    }
    buffer.write('\r\n');
    socket.write(buffer.toString());
    socket.flush();
  }

  Future<Socket> _performWsHandshakeResponse(Socket socket) async {
    final controller = StreamController<Uint8List>();
    final completer = Completer<void>();
    final buffer = BytesBuilder();
    bool headersFinished = false;

    // Use field _subscription to track the primary WS connection subscription
    // This listener intercepts the WebSocket handshake response.
    // If 'socket' is a _SocketWrapper, its listen() method will connect to the
    // stream of the previous layer (e.g., from proxy or secure socket).
    _subscription = socket.listen(
      (data) {
        if (headersFinished) {
          controller.add(data); // Pass through actual WebSocket frames
          return;
        }

        buffer.add(data);
        final bytes = buffer.toBytes();
        final doubleCrlfIndex = _findDoubleCrlf(bytes);

        if (doubleCrlfIndex != -1) {
          headersFinished = true;

          // Extract headers
          final headerBytes = bytes.sublist(0, doubleCrlfIndex + 4);
          final headerStr = utf8.decode(headerBytes);

          // Check Status
          if (!headerStr.toUpperCase().startsWith('HTTP/1.1 101') &&
              !headerStr.toUpperCase().startsWith('HTTP/1.0 101')) {
            if (!completer.isCompleted) {
              completer.completeError(
                Exception("WebSocket Upgrade Failed:\n$headerStr"),
              );
            }
            return;
          }

          // Push remaining bytes (if any) to proxy
          if (bytes.length > doubleCrlfIndex + 4) {
            controller.add(bytes.sublist(doubleCrlfIndex + 4));
          }

          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
        controller.addError(e);
      },
      onDone: () {
        if (!completer.isCompleted && !headersFinished) {
          completer.completeError(Exception("Socket closed before handshake"));
        }
        controller.close();
      },
    );

    await completer.future; // Wait for the WebSocket handshake to complete
    return _SocketWrapper(socket, controller.stream);
  }

  int _findDoubleCrlf(Uint8List bytes) {
    if (bytes.length < 4) return -1;
    for (var i = 0; i <= bytes.length - 4; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    // We should cancel the subscription to the RAW socket if channel is closed?
    // Usually `WebSocket` logic handles closing underlying socket.
    // Since we wrapped it, `WebSocket` calls `wrapper.close()`.
    // `wrapper.close()` delegates to `socket.close()`.
    // `socket.close()` sends FIN.
    // The stream might end.
    // _subscription onDone will close proxyController.

    // Just to be safe:
    // _subscription?.cancel(); // If we own it.
    // But we ceded control to the flow.
  }

  void send(String message) {
    if (_channel == null) throw Exception("Not connected");
    _channel!.sink.add(message);
  }

  Stream<dynamic>? getStream() {
    return _channel?.stream;
  }

  bool get isConnected => _channel != null;
}

/// Wraps a Socket to intercept/replace the input stream
class _SocketWrapper extends StreamView<Uint8List> implements Socket {
  final Socket _socket;

  _SocketWrapper(this._socket, Stream<Uint8List> stream) : super(stream);

  @override
  InternetAddress get address => _socket.address;
  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;
  @override
  int get port => _socket.port;
  @override
  int get remotePort => _socket.remotePort;
  @override
  Future get done => _socket.done;
  @override
  void destroy() => _socket.destroy();
  @override
  void add(List<int> data) => _socket.add(data);
  @override
  void write(Object? object) => _socket.write(object);
  @override
  void writeAll(Iterable objects, [String separator = ""]) =>
      _socket.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);
  @override
  void writeln([Object? object = ""]) => _socket.writeln(object);
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);
  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);
  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
  @override
  Future<void> close() => _socket.close();

  @override
  Encoding get encoding => _socket.encoding;
  @override
  set encoding(Encoding value) => _socket.encoding = value;
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);
  @override
  Future addStream(Stream<List<int>> stream) => _socket.addStream(stream);
  @override
  Future flush() => _socket.flush();
}

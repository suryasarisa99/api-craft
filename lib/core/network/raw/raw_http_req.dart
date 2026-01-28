import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:api_craft/core/network/raw/parse_raw_response.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/network/cookie_utils.dart';
import 'package:api_craft/core/utils/parsers.dart';
import 'package:flutter/foundation.dart';

Future<ResponseHistory> sendRawHttp({
  required String method,
  required Uri url,
  List<List<String>>? headers,
  dynamic body,
  bool useProxy = false,
  String proxyHost = '127.0.0.1',
  int proxyPort = 8080,
  String? proxyUsername,
  String? proxyPassword,
  String proxyProtocol = 'http',
  required String requestId,
  Duration connectTimeout = const Duration(seconds: 10),
  int maxRedirects = 5,
  bool followRedirects = true,
  List<CookieDef> cookiesJar = const [],
}) async {
  Uri currentUrl = url;
  int redirectCount = 0;

  // Track state across redirects
  String currentMethod = method;
  dynamic currentBody = body;

  // Cookies for the session
  // We use a mutable list to track cookies across redirects
  List<CookieDef> currentCookies = List.from(cookiesJar);
  // Mutable headers list
  List<List<String>> currentHeaders = headers != null
      ? List<List<String>>.from(headers)
      : [];

  // History tracking
  List<RedirectStep> redirects = [];
  final requestSentTime = DateTime.now(); // Start time of validation sequence

  if (!followRedirects) {
    maxRedirects = 0;
  }

  while (redirectCount <= maxRedirects) {
    final stepStartTime = DateTime.now(); // Start time of THIS step

    // Per-request variables
    List<List<String>> stepReqHeaders = [];
    String? stepReqBodyStr;
    bool stepHasBody = false;

    // 1. Prepare Connection
    final isHttps = currentUrl.scheme == 'https';
    final port = (currentUrl.port == 0)
        ? (isHttps ? 443 : 80)
        : currentUrl.port;

    late Socket socket;

    try {
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
        var connectReq =
            'CONNECT ${currentUrl.host}:$port HTTP/1.1\r\n'
            'Host: ${currentUrl.host}:$port\r\n';

        if (proxyUsername != null && proxyPassword != null) {
          final auth =
              'Basic ${base64Encode(utf8.encode('$proxyUsername:$proxyPassword'))}';
          connectReq += 'Proxy-Authorization: $auth\r\n';
        }
        connectReq += '\r\n';
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

      // 3. Build Request
      final path = (useProxy && !isHttps)
          ? currentUrl.toString()
          : (currentUrl.path.isEmpty ? "/" : currentUrl.path) +
                (currentUrl.hasQuery ? "?${currentUrl.query}" : "");

      final buffer = StringBuffer();
      buffer.write('$currentMethod $path HTTP/1.1\r\n');

      // headers setup
      final defaultPort = isHttps ? 443 : 80;
      final hostHeader =
          (currentUrl.port == 0 || currentUrl.port == defaultPort)
          ? currentUrl.host
          : '${currentUrl.host}:${currentUrl.port}';

      buffer.write('Host: $hostHeader\r\n');
      stepReqHeaders.add(['Host', hostHeader]);

      bool hasConnectionHeader = false;
      bool hasAcceptEncoding = false;
      bool hasContentLength = false;
      List<String> userManualCookies = [];

      // Add User Headers
      if (currentHeaders.isNotEmpty) {
        for (final h in currentHeaders) {
          if (h.length != 2) continue;
          final keyLower = h[0].toLowerCase();

          if (keyLower == 'host') continue; // Skip manually added Host
          if (keyLower == 'connection') hasConnectionHeader = true;
          if (keyLower == 'accept-encoding') hasAcceptEncoding = true;
          if (keyLower == 'content-length') hasContentLength = true;

          if (keyLower == 'cookie') {
            userManualCookies.add(h[1]);
            continue; // We handle cookies properly later
          }

          // Logic: For redirects, we might want to strip sensitive headers if domain changes?
          // Standard practice: Authorization, Cookie, Proxy-Authorization.
          // For now, we simple-mindedly forward everything EXCEPT Cookies which we handle specially.

          // Note: 'cookie' is already skipped above.

          buffer.write('${h[0]}: ${h[1]}\r\n');
          stepReqHeaders.add([h[0], h[1]]);
        }
      }

      // Cookie Injection
      // We calculate relevant cookies from our CookieJar snapshot + updates
      final relevantCookies = CookieUtils.getRelevantCookies(
        currentUrl,
        currentCookies,
      );

      // Support for duplicate vs merged cookies
      if (userManualCookies.length <= 1) {
        // SCENARIO 1: User provided single cookie header.
        // We merge Jar cookies into it (standard modern behavior + user convenience)
        // Result: Cookie: user=val; jar=val
        String combined = userManualCookies.firstOrNull ?? '';
        if (relevantCookies.isNotEmpty) {
          final jarCookieStr = CookieUtils.generateCookieHeader(
            relevantCookies,
          );
          if (combined.isEmpty) {
            combined = jarCookieStr;
          } else if (combined.trim().endsWith(';')) {
            combined += ' $jarCookieStr';
          } else {
            combined += '; $jarCookieStr';
          }
        }
        buffer.write('Cookie: $combined\r\n');
        stepReqHeaders.add(['Cookie', combined]);
      } else {
        // SCENARIO 2: User provided MULTIPLE cookie headers (or zero).
        // If multiple, they likely want to support legacy/custom behavior (separate headers).
        // So we write them out separately, and append Jar cookies as yet another separate header.

        for (final uc in userManualCookies) {
          buffer.write('Cookie: $uc\r\n');
          stepReqHeaders.add(['Cookie', uc]);
        }

        if (relevantCookies.isNotEmpty) {
          final jarCookieStr = CookieUtils.generateCookieHeader(
            relevantCookies,
          );
          buffer.write('Cookie: $jarCookieStr\r\n');
          stepReqHeaders.add(['Cookie', jarCookieStr]);
        }
      }

      if (!hasConnectionHeader) {
        buffer.write('Connection: close\r\n');
        stepReqHeaders.add(['Connection', 'close']);
      }

      // Proxy Auth
      if (useProxy &&
          !isHttps &&
          proxyUsername != null &&
          proxyPassword != null) {
        // ... (existing proxy logic, assuming headers didn't cover it)
        // Actually we should check if header acts for it. Logic simplification: Just add if needed.
        // But wait, we added it in loop if passed in headers? No, proxy auth is usually separate arg.
        final auth =
            'Basic ${base64Encode(utf8.encode('$proxyUsername:$proxyPassword'))}';
        buffer.write('Proxy-Authorization: $auth\r\n');
        stepReqHeaders.add(['Proxy-Authorization', auth]);
      }

      if (!hasAcceptEncoding) {
        buffer.write('Accept-Encoding: gzip\r\n');
        stepReqHeaders.add(['Accept-Encoding', 'gzip']);
      }

      // Body Handling
      List<int> bodyBytesToSend = [];
      if (currentBody != null) {
        // Only send body if method supports it / needs it.
        // Actually we rely on `currentBody` being set to null if method changed to GET.

        if (currentBody is String) {
          stepReqBodyStr = currentBody;
          bodyBytesToSend = utf8.encode(currentBody);
        } else if (currentBody is List<int>) {
          try {
            stepReqBodyStr = utf8.decode(currentBody, allowMalformed: true);
          } catch (_) {
            stepReqBodyStr = "<binary data>";
          }
          bodyBytesToSend = currentBody;
        }

        if (bodyBytesToSend.isNotEmpty) {
          stepHasBody = true;
          if (!hasContentLength) {
            buffer.write('Content-Length: ${bodyBytesToSend.length}\r\n');
            stepReqHeaders.add(['Content-Length', '${bodyBytesToSend.length}']);
          }
        }
      }

      buffer.write('\r\n'); // End of headers

      // Write & Flush
      socket.write(buffer.toString());
      if (bodyBytesToSend.isNotEmpty) socket.add(bodyBytesToSend);
      await socket.flush();

      // Read Response
      final allBytes = await socket
          .fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d))
          .then((b) => b.toBytes());
      await socket.close();

      // Parse Response
      final response = parseRawResponse(
        allBytes,
        requestId: requestId,
        redirects: [], // Deprecated in logic but required by parser?
        isHeadRequest: currentMethod == 'HEAD',
      );

      // Handle Set-Cookie from response
      final setCookies = RawHeaderUtils.getSetCookies(
        response.headers,
        currentUrl,
      );
      if (setCookies.isNotEmpty) {
        // Merge into currentCookies
        // Logic: Remove old cookies with same name/domain/path and add new one
        // Simple implementation: Just add to list, assuming utils will filter/pick latest if needed?
        // Better: Update list.
        for (var sc in setCookies) {
          currentCookies.removeWhere(
            (c) =>
                c.key == sc.key && c.domain == sc.domain && c.path == sc.path,
          );
          currentCookies.add(sc);
        }
      }

      // Check for Redirect
      final status = response.statusCode;
      final isRedirect = [301, 302, 303, 307, 308].contains(status);

      // Calc duration for this step
      final stepEndTime = DateTime.now();
      final stepDurationMs = stepEndTime
          .difference(stepStartTime)
          .inMilliseconds;

      if (isRedirect && redirectCount < maxRedirects) {
        final location = response.headers
            .firstWhere(
              (h) => h[0].toLowerCase() == 'location',
              orElse: () => [],
            )
            .elementAtOrNull(1);

        if (location != null && location.isNotEmpty) {
          // Record Redirect Step
          redirects.add(
            RedirectStep(
              statusCode: status,
              method: currentMethod,
              url: currentUrl.toString(),
              reqHeaders: stepReqHeaders,
              resHeaders: response.headers,
              hasBody: stepHasBody,
              durationMs: stepDurationMs,
            ),
          );

          redirectCount++;

          // Resolve new URL
          final newUri = Uri.parse(location);
          final nextUrl = newUri.hasScheme
              ? newUri
              : currentUrl.resolve(location);

          // Decide Method & Body for next request
          // 301, 302, 303 -> GET, No Body
          // 307, 308 -> Keep Method, Keep Body
          if (status == 301 || status == 302 || status == 303) {
            currentMethod = 'GET';
            currentBody = null;
          }
          // 307/308 preserve method/body (so currentMethod/currentBody remain same)

          // Strip sensitive headers if domain changes
          if (nextUrl.host != currentUrl.host) {
            currentHeaders = currentHeaders.where((h) {
              final key = h[0].toLowerCase();
              return key != 'authorization' &&
                  key != 'cookie' &&
                  key != 'proxy-authorization' &&
                  key != 'www-authenticate';
            }).toList();
          }

          currentUrl = nextUrl;
          debugPrint(
            "Redirecting to: $currentUrl ($redirectCount/$maxRedirects)",
          );
          continue;
        }
      }

      // Final Response Logic
      final responseReceivedTime = DateTime.now();
      final durationMs = responseReceivedTime
          .difference(requestSentTime)
          .inMilliseconds;

      // Parse again or reconstruct with full info?
      // `parseRawResponse` helper is a bit simplistic. We can construct ResponseHistory directly now.
      // But `parseRawResponse` parses headers/body from bytes which is useful.
      // Let's reuse `response` object but populate missing fields.

      return response.copyWith(
        executeAt: requestSentTime,
        durationMs: durationMs,
        redirects: redirects,
        finalUrl: currentUrl.toString(),
        reqHeaders: stepReqHeaders,
        reqBody: stepReqBodyStr,
        headers: response.headers, // ensure headers are set
      );
    } catch (e) {
      try {
        socket.destroy();
      } catch (_) {}
      rethrow;
    }
  }
  debugPrint("Max redirects exceeded or loop error");

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

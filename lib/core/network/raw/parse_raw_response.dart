import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/response/models/response_history.dart';
import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';

/// Helper: Parses the raw bytes into a structured Object
ResponseHistory parseRawResponse(
  Uint8List allBytes, {
  required String requestId,
  List<RedirectStep> redirects = const [],
  String? finalUrl,
  bool isHeadRequest = false,
}) {
  // Find the double CRLF separating headers from body
  int splitIndex = -1;
  for (int i = 0; i < allBytes.length - 3; i++) {
    if (allBytes[i] == 13 &&
        allBytes[i + 1] == 10 &&
        allBytes[i + 2] == 13 &&
        allBytes[i + 3] == 10) {
      splitIndex = i;
      break;
    }
  }

  // Fallback if no body or malformed
  if (splitIndex == -1) {
    splitIndex = allBytes.length;
  }

  // A. Parse Headers
  final headerBytes = allBytes.sublist(0, splitIndex);
  final headerString = utf8.decode(headerBytes, allowMalformed: true);

  // Use LineSplitter but handle folding manually if needed,
  // currently we'll just split by line and process folding in the loop.
  // Actually, standard LineSplitter kills \r\n, identifying usage is safer if we just split by \n and trim?
  // Let's stick to LineSplitter for simplicity but we might need to reconstruct if we want to support folding meticulously.
  // The 'headerLines' logic below implementation essentially ignores folding.
  // To support folding:
  // If a line starts with space or tab, append to previous line.

  final rawLines = LineSplitter.split(headerString).toList();
  final List<String> headerLines = [];

  for (var line in rawLines) {
    if (line.isEmpty) continue;
    if (line.startsWith(' ') || line.startsWith('\t')) {
      // Folding: append to previous
      if (headerLines.isNotEmpty) {
        headerLines[headerLines.length - 1] += ' ${line.trim()}';
      }
    } else {
      headerLines.add(line);
    }
  }

  // A1. Status Line (HTTP/1.1 200 OK)
  String protocol = "HTTP/1.1";
  int statusCode = 0;
  String statusMsg = "";

  if (headerLines.isNotEmpty) {
    final statusLine = headerLines[0];
    final firstSpace = statusLine.indexOf(' ');

    if (firstSpace != -1) {
      protocol = statusLine.substring(0, firstSpace);
      final secondSpace = statusLine.indexOf(' ', firstSpace + 1);

      if (secondSpace != -1) {
        statusCode =
            int.tryParse(statusLine.substring(firstSpace + 1, secondSpace)) ??
            0;
        statusMsg = statusLine.substring(secondSpace + 1);
      } else {
        statusCode = int.tryParse(statusLine.substring(firstSpace + 1)) ?? 0;
      }
    }
  }

  // A2. Header Map
  final List<List<String>> headersList = [];
  for (int i = 1; i < headerLines.length; i++) {
    final line = headerLines[i];
    final idx = line.indexOf(':');
    if (idx != -1) {
      headersList.add([
        line.substring(0, idx).trim(),
        line.substring(idx + 1).trim(),
      ]);
    }
  }
  debugPrint("parsed headers len: ${headersList.length}");

  // B. Extract Body
  // skip the \r\n\r\n (4 bytes)
  Uint8List rawBodyBytes = (splitIndex + 4 < allBytes.length)
      ? allBytes.sublist(splitIndex + 4)
      : Uint8List(0);

  // Check for empty body conditions
  bool shouldHaveEmptyBody =
      isHeadRequest ||
      statusCode == 204 ||
      statusCode == 304 ||
      (statusCode >= 100 && statusCode < 200);

  if (shouldHaveEmptyBody) {
    rawBodyBytes = Uint8List(0);
  } else {
    // C. Handle Transfer-Encoding: chunked
    String transferEncoding = '';
    for (final h in headersList) {
      if (h[0].toLowerCase() == 'transfer-encoding') {
        transferEncoding = h[1].toLowerCase();
        break;
      }
    }

    if (transferEncoding.contains('chunked')) {
      final decoded = _decodeChunkedBody(
        rawBodyBytes,
        headersList,
      ); // Pass headersList to append trailers
      rawBodyBytes = decoded;
    } else {
      // Fix 5: Respect Content-Length if not chunked
      int? contentLength;
      for (final h in headersList) {
        if (h[0].toLowerCase() == 'content-length') {
          contentLength = int.tryParse(h[1]);
          break;
        }
      }
      if (contentLength != null &&
          contentLength >= 0 &&
          rawBodyBytes.length > contentLength) {
        rawBodyBytes = rawBodyBytes.sublist(0, contentLength);
      }
    }
  }

  // D. Handle Gzip Encoding
  // Only decode if we actually have bytes
  if (rawBodyBytes.isNotEmpty) {
    String contentEncoding = '';
    for (final h in headersList) {
      if (h[0].toLowerCase() == 'content-encoding') {
        contentEncoding = h[1].toLowerCase();
        break;
      }
    }

    if (contentEncoding.contains('gzip')) {
      try {
        rawBodyBytes = Uint8List.fromList(gzip.decode(rawBodyBytes));
      } catch (e) {
        debugPrint("Gzip decode failed: $e");
      }
    }
  }

  // E. Extract bodyType from Content-Type
  String? bodyType;
  for (final h in headersList) {
    if (h[0].toLowerCase() == 'content-type') {
      bodyType = h[1].toLowerCase();
      break;
    }
  }

  return ResponseHistory(
    id: nanoid(),
    requestId: requestId,
    statusCode: statusCode,
    statusMessage: statusMsg,
    protocolVersion: protocol,
    executeAt: DateTime.now(), // Caller should override
    durationMs: 0, // Caller should override
    // headers: headersMap,
    headers: headersList,
    bodyBytes: rawBodyBytes,
    bodyType: bodyType,
    redirects: redirects,
    finalUrl: finalUrl,
  );
}

/// Helper: Manually decodes Chunked Transfer Encoding
/// Also extracts trailers and adds them to [headersList]
Uint8List _decodeChunkedBody(Uint8List bytes, List<List<String>> headersList) {
  final buffer = BytesBuilder();
  int offset = 0;

  while (offset < bytes.length) {
    // Find end of chunk size line
    int lineEnd = -1;
    for (int i = offset; i < bytes.length - 1; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10) {
        lineEnd = i;
        break;
      }
    }

    if (lineEnd == -1) break; // Incomplete chunk header

    // Parse chunk size (hex)
    // Fix: Handle chunk extensions (e.g., "1A; ext=val")
    final sizeLineRaw = String.fromCharCodes(bytes.sublist(offset, lineEnd));
    final sizeStr = sizeLineRaw.split(';').first.trim();
    final chunkSize = int.tryParse(sizeStr, radix: 16);

    if (chunkSize == null) break; // Error parsing

    // Move offset to beginning of data (skip CRLF)
    offset = lineEnd + 2;

    if (chunkSize == 0) {
      // End of stream (0-sized chunk)
      // Fix: Handle Trailers
      // Trailers extend until empty line (CRLF CRLF)
      // We need to parse lines from `offset` until we hit empty line

      // Sliced remaining bytes for trailer parsing
      if (offset < bytes.length) {
        final remaining = bytes.sublist(offset);
        // Simple search for double CRLF to find end of trailers block
        int trailersEnd = -1;
        for (int i = 0; i < remaining.length - 3; i++) {
          if (remaining[i] == 13 &&
              remaining[i + 1] == 10 &&
              remaining[i + 2] == 13 &&
              remaining[i + 3] == 10) {
            trailersEnd = i;
            break;
          }
        }

        if (trailersEnd != -1) {
          // We have trailers
          final trailerBlock = remaining.sublist(0, trailersEnd);

          final trailerString = utf8.decode(trailerBlock, allowMalformed: true);
          final trailerLines = LineSplitter.split(trailerString).toList();

          // Handle folding for trailers too
          List<String> processedTrailerLines = [];
          for (var line in trailerLines) {
            if (line.isEmpty) continue;
            if (line.startsWith(' ') || line.startsWith('\t')) {
              if (processedTrailerLines.isNotEmpty) {
                processedTrailerLines[processedTrailerLines.length - 1] +=
                    ' ${line.trim()}';
              }
            } else {
              processedTrailerLines.add(line);
            }
          }

          for (final line in processedTrailerLines) {
            final idx = line.indexOf(':');
            if (idx != -1) {
              headersList.add([
                line.substring(0, idx).trim(),
                line.substring(idx + 1).trim(),
              ]);
            }
          }
        }
      }

      break;
    }

    // Validate chunk trailing CRLF exists if we have enough bytes
    if (offset + chunkSize + 2 <= bytes.length) {
      if (bytes[offset + chunkSize] != 13 ||
          bytes[offset + chunkSize + 1] != 10) {
        break; // Malformed chunk
      }
    }

    if (offset + chunkSize > bytes.length) {
      // Incomplete data, take what we have or break
      buffer.add(bytes.sublist(offset));
      break;
    }

    buffer.add(bytes.sublist(offset, offset + chunkSize));

    // Move offset past data + trailing CRLF
    offset += chunkSize + 2;
  }
  return buffer.toBytes();
}

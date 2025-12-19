import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_craft/core/models/models.dart';
import 'package:flutter/material.dart';

/// Helper: Parses the raw bytes into a structured Object
RawHttpResponse parseRawResponse(
  Uint8List allBytes, {

  required DateTime requestSentTime,
  required int durationMs,
  required String requestId,
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
  final headerLines = LineSplitter.split(headerString).toList();

  // A1. Status Line (HTTP/1.1 200 OK)
  String protocol = "HTTP/1.1";
  int statusCode = 0;
  String statusMsg = "";

  if (headerLines.isNotEmpty) {
    final statusLine = headerLines[0];
    final parts = statusLine.split(' ');
    if (parts.length >= 2) {
      protocol = parts[0];
      statusCode = int.tryParse(parts[1]) ?? 0;
      statusMsg = parts.length > 2 ? parts.sublist(2).join(' ') : "";
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

  // C. Handle Transfer-Encoding: chunked
  String transferEncoding = '';
  for (final h in headersList) {
    if (h[0].toLowerCase() == 'transfer-encoding') {
      transferEncoding = h[1].toLowerCase();
      break;
    }
  }

  if (transferEncoding.contains('chunked')) {
    rawBodyBytes = _decodeChunkedBody(rawBodyBytes);
  }

  // D. Handle Gzip Encoding
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

  return RawHttpResponse(
    id: uuid.v4(),
    requestId: requestId,
    statusCode: statusCode,
    statusMessage: statusMsg,
    protocolVersion: protocol,
    executeAt: requestSentTime,
    durationMs: durationMs,
    // headers: headersMap,
    headers: headersList,
    bodyBytes: rawBodyBytes,
    body: utf8.decode(rawBodyBytes, allowMalformed: true),
  );
}

/// Helper: Manually decodes Chunked Transfer Encoding
Uint8List _decodeChunkedBody(Uint8List bytes) {
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
    final sizeLine = String.fromCharCodes(bytes.sublist(offset, lineEnd));
    final chunkSize = int.tryParse(sizeLine, radix: 16);

    if (chunkSize == null) break; // Error parsing
    if (chunkSize == 0) break; // End of stream

    // Move offset to data start (skip CRLF)
    offset = lineEnd + 2;

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

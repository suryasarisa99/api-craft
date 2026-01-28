import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Simple icon cache.
///
/// - In-memory cache: keeps decoded bytes and `MemoryImage` providers to avoid
///   repeated base64 decoding while widget/tree is live.
/// - Disk cache: stores decoded bytes in a temp cache directory so subsequent
///   runs or rebuilds can reuse the file and avoid expensive base64 decode.
class IconCache {
  IconCache._();

  static final Map<String, Uint8List> _bytesCache = {};
  static final Map<String, MemoryImage> _imageProviderCache = {};

  /// Directory under system temp where icons are persisted.
  static Directory get _cacheDir =>
      Directory('${Directory.systemTemp.path}/mitmui_icon_cache');

  /// Return a [MemoryImage] for given base64 string. Decodes once and caches in-memory.
  static MemoryImage providerFromBase64(String base64) {
    final key = base64;
    final cached = _imageProviderCache[key];
    if (cached != null) return cached;

    final bytes = _bytesCache[key] ?? base64Decode(base64);
    _bytesCache[key] = bytes;
    final provider = MemoryImage(bytes);
    _imageProviderCache[key] = provider;
    return provider;
  }

  /// Asynchronously ensure the base64 image is written to disk and return a FileImage.
  /// The file name uses the base64's hashCode and length to avoid very long names.
  static Future<FileImage> fileProviderFromBase64(String base64) async {
    final key = '${base64.hashCode}_${base64.length}';
    if (!await _cacheDir.exists()) await _cacheDir.create(recursive: true);

    // Try to find an existing file with this key prefix.
    final existing = _cacheDir.listSync().cast<File>().firstWhere(
      (f) => f.path.split(Platform.pathSeparator).last.startsWith(key),
      orElse: () => File(''),
    );
    if (existing.path.isNotEmpty && await existing.exists()) {
      return FileImage(existing);
    }

    // decode and detect extension
    final bytes = _bytesCache[key] ?? base64Decode(base64);
    _bytesCache[key] = bytes;

    String ext = 'bin';
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      ext = 'png';
    } else if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      ext = 'jpg';
    } else if (bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49) {
      ext = 'gif';
    }

    final file = File('${_cacheDir.path}${Platform.pathSeparator}$key.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return FileImage(file);
  }

  /// Convenience widget that displays a cached disk-backed image.
  /// Shows a placeholder while the file is prepared.
  static Widget imageFromBase64Cached(
    String base64Str, {
    double? width,
    double? height,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    Widget? placeholder,
    String? semanticLabel,
  }) {
    final Widget ph = placeholder ?? SizedBox(width: width, height: height);
    return FutureBuilder<FileImage>(
      future: fileProviderFromBase64(base64Str),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          return Image(
            image: snap.data!,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            semanticLabel: semanticLabel,
          );
        }
        return ph;
      },
    );
  }

  /// Clear caches (useful for tests or memory pressure handling).
  static void clear() {
    _bytesCache.clear();
    _imageProviderCache.clear();
    try {
      if (_cacheDir.existsSync()) {
        _cacheDir.listSync().forEach((f) => f.deleteSync());
      }
    } catch (_) {}
  }
}

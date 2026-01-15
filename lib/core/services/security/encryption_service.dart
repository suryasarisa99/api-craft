import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final encryptionServiceProvider = Provider((ref) => EncryptionService());

class EncryptionService {
  final _algorithm = Xchacha20.poly1305Aead();

  // === Primitives ===

  /// Generates a random 32-byte key
  List<int> generateRandomKey() {
    final random = Random.secure();
    return List<int>.generate(32, (i) => random.nextInt(256));
  }

  /// Encrypts string data using XChaCha20-Poly1305
  /// Returns format: ENC_<nonce_b64>_<ciphertext_b64>__<mac_b64>
  Future<String> encrypt(String plaintext, List<int> key) async {
    final secretKey = await _algorithm.newSecretKeyFromBytes(key);
    final nonce = _algorithm.newNonce();

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    final nonceB64 = base64Encode(secretBox.nonce);
    final ciphertextB64 = base64Encode(secretBox.cipherText);
    final macB64 = base64Encode(secretBox.mac.bytes);

    return "ENC_${nonceB64}_${ciphertextB64}__$macB64";
  }

  /// Decrypts data using XChaCha20-Poly1305
  Future<String> decrypt(String encryptedFormat, List<int> key) async {
    if (!encryptedFormat.startsWith('ENC_')) {
      throw Exception("Invalid encryption format");
    }

    try {
      final parts = encryptedFormat.substring(4).split('__');
      if (parts.length != 2) throw Exception("Invalid structure");

      final macB64 = parts[1];
      final contentParts = parts[0].split('_');
      if (contentParts.length != 2)
        throw Exception("Invalid content structure");

      final nonceB64 = contentParts[0];
      final ciphertextB64 = contentParts[1];

      final secretKey = await _algorithm.newSecretKeyFromBytes(key);
      final nonce = base64Decode(nonceB64);
      final ciphertext = base64Decode(ciphertextB64);
      final mac = Mac(base64Decode(macB64));

      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);

      final clearTextBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(clearTextBytes);
    } catch (e) {
      throw Exception("Decryption failed: $e");
    }
  }

  /// Wraps (encrypts) a Workspace Key using the Master Key
  Future<String> wrapKey(List<int> keyToWrap, List<int> wrappingKey) async {
    final secretKey = await _algorithm.newSecretKeyFromBytes(wrappingKey);
    final nonce = _algorithm.newNonce();

    final secretBox = await _algorithm.encrypt(
      keyToWrap,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Format: KEY_<nonce>_<ciphertext>_<mac>
    final nonceB64 = base64Encode(secretBox.nonce);
    final ciphertextB64 = base64Encode(secretBox.cipherText);
    final macB64 = base64Encode(secretBox.mac.bytes);

    return "KEY_${nonceB64}_${ciphertextB64}_$macB64";
  }

  /// Unwraps (decrypts) a Workspace Key using the Master Key
  Future<List<int>> unwrapKey(String wrappedKey, List<int> wrappingKey) async {
    if (!wrappedKey.startsWith('KEY_')) {
      throw Exception("Invalid key format");
    }
    try {
      final parts = wrappedKey.substring(4).split('_');
      if (parts.length != 3) throw Exception("Invalid key structure");

      final nonce = base64Decode(parts[0]);
      final ciphertext = base64Decode(parts[1]);
      final mac = Mac(base64Decode(parts[2]));

      final secretKey = await _algorithm.newSecretKeyFromBytes(wrappingKey);
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);

      final keyBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return keyBytes;
    } catch (e) {
      debugPrint("Unwrap failed: $e");
      if (e.toString().contains("Invalid key")) rethrow;
      throw Exception("Key unwrapping failed: $e");
    }
  }
}

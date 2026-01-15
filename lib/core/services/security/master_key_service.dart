import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/services/security/encryption_service.dart';

final masterKeyProvider = NotifierProvider<MasterKeyProvider, List<int>?>(
  MasterKeyProvider.new,
);

class MasterKeyProvider extends Notifier<List<int>?> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  late EncryptionService _encryptionService;
  static const _keyName = 'api_craft_master_key';

  @override
  List<int>? build() {
    _encryptionService = ref.read(encryptionServiceProvider);
    getMasterKey().then((value) => state = value);
    return null;
  }

  Future<List<int>> generateMasterKey() async {
    // 1. Generate new key
    final newKey = _encryptionService.generateRandomKey();

    // 2. Store securely
    await _storage.write(
      key: _keyName,
      value: base64Encode(newKey),
      aOptions: const AndroidOptions(),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
      mOptions: const MacOsOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );
    state = newKey;
    return newKey;
  }

  Future<List<int>?> getMasterKey() async {
    final storedKey = await _storage.read(key: _keyName);
    if (storedKey != null) {
      state = base64Decode(storedKey);
      return state!;
    }
    return null;
  }
}

// class MasterKeyService {
//   final FlutterSecureStorage _storage;
//   final EncryptionService _encryptionService;
//   static const _keyName = 'api_craft_master_key';

//   MasterKeyService(this._storage, this._encryptionService);

//   List<int>? _cachedKey;

//   Future<List<int>> generateMasterKey() async {
//     debugPrint("MasterKeyService: Generating new master key.");
//     // 1. Generate new key
//     final newKey = _encryptionService.generateRandomKey();

//     // 2. Store securely
//     await _storage.write(
//       key: _keyName,
//       value: base64Encode(newKey),
//       aOptions: const AndroidOptions(),
//       iOptions: const IOSOptions(
//         accessibility: KeychainAccessibility.first_unlock,
//       ),
//       mOptions: const MacOsOptions(
//         accessibility: KeychainAccessibility.unlocked_this_device,
//       ),
//     );

//     debugPrint("MasterKeyService: New master key saved to storage.");
//     _cachedKey = newKey;
//     return newKey;
//   }

//   Future<List<int>> getMasterKey() async {
//     if (_cachedKey != null) {
//       return _cachedKey!;
//     }

//     final storedKey = await _storage.read(key: _keyName);
//     if (storedKey != null) {
//       debugPrint("MasterKeyService: Found existing master key.");
//       _cachedKey = base64Decode(storedKey);
//       return _cachedKey!;
//     }
//     throw Exception("Master key not found");
//   }
// }

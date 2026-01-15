import 'package:api_craft/core/services/security/encryption_service.dart';
import 'package:api_craft/core/services/security/master_key_service.dart';
import 'package:api_craft/core/repository/data_repository.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/collection/collection_model.dart';
import 'package:api_craft/features/sidebar/file_tree_provider.dart';
import 'package:api_craft/core/database/entities/collection_entity.dart';
import 'package:api_craft/objectbox.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:api_craft/features/collection/collections_provider.dart';

final collectionSecurityServiceProvider = Provider(
  (ref) => CollectionSecurityService(ref),
);

class CollectionSecurityService {
  final Ref ref;
  late final _encryptionService = ref.read(encryptionServiceProvider);

  CollectionSecurityService(this.ref);

  List<int> getMasterKey() {
    final masterKey = ref.read(masterKeyProvider);
    return masterKey!;
  }

  Future<List<int>> getMasterKeyAsync() async {
    final masterKey = await ref.read(masterKeyProvider.notifier).getMasterKey();
    return masterKey!;
  }

  /// Enables encryption for a collection.
  /// 1. Generates a new random Workspace Key
  /// 2. Wraps it with the Master Key
  /// 3. Saves the encrypted key to the collection metadata in DB
  Future<void> enableEncryption(String collectionId) async {
    final repo = ref.read(repositoryProvider); // Use store repo abstraction

    // Check if checks already encrypted
    // (Optimization: can check collection model in memory first)

    List<int> masterKey;
    try {
      masterKey = await getMasterKeyAsync();
    } catch (_) {
      throw Exception("Master key not found");
    }

    final workspaceKey = _encryptionService.generateRandomKey();

    final encryptedWorkspaceKey = await _encryptionService.wrapKey(
      workspaceKey,
      masterKey,
    );

    // Update Collection in DB
    // We need to update directly via repository to ensure persistence
    await repo.setCollectionEncryption(collectionId, encryptedWorkspaceKey);

    // Refresh FileTree to reflect changes instantly without reload
    ref
        .read(fileTreeProvider.notifier)
        .updateEncryptionKey(collectionId, encryptedWorkspaceKey);
  }

  /// Gets the unwrapped Workspace Key for a collection
  Future<List<int>> getCollectionKey() async {
    final collectionNode = ref.read(collectionNodeProvider);
    if (collectionNode == null) {
      throw Exception("No collection selected");
    }

    final encryptedKey = collectionNode.folderConfig.encryptedKey;
    if (encryptedKey == null) {
      throw Exception("Encryption not enabled for this collection");
    }

    final masterKey = await getMasterKeyAsync();
    return await _encryptionService.unwrapKey(encryptedKey, masterKey);
  }

  /// Encrypts data for a specific collection
  Future<String> encryptData(String plaintext) async {
    final key = await getCollectionKey();
    return await _encryptionService.encrypt(plaintext, key);
  }

  /// Decrypts data for a specific collection
  Future<String> decryptData(String ciphertext) async {
    try {
      final key = await getCollectionKey();
      return await _encryptionService.decrypt(ciphertext, key);
    } catch (err) {
      debugPrint("error: ${err.toString()}");
      throw Exception("Failed to decrypt data");
    }
  }
}

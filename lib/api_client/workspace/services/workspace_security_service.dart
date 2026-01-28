import 'package:api_craft/core/services/security/encryption_service.dart';
import 'package:api_craft/core/services/security/master_key_service.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workspaceSecurityServiceProvider = Provider(
  (ref) => WorkspaceSecurityService(ref),
);

class WorkspaceSecurityService {
  final Ref ref;
  late final _encryptionService = ref.read(encryptionServiceProvider);

  WorkspaceSecurityService(this.ref);

  List<int> getMasterKey() {
    final masterKey = ref.read(masterKeyProvider);
    return masterKey!;
  }

  Future<List<int>> getMasterKeyAsync() async {
    final masterKey = await ref.read(masterKeyProvider.notifier).getMasterKey();
    return masterKey!;
  }

  /// Enables encryption for a workspace.
  /// 1. Generates a new random Workspace Key
  /// 2. Wraps it with the Master Key
  /// 3. Saves the encrypted key to the workspace metadata in DB
  Future<void> enableEncryption(String workspaceId) async {
    final repo = ref.read(repositoryProvider); // Use store repo abstraction

    // Check if checks already encrypted
    // (Optimization: can check workspace model in memory first)

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

    // Update Workspace in DB
    // We need to update directly via repository to ensure persistence
    await repo.setWorkspaceEncryption(workspaceId, encryptedWorkspaceKey);

    // Refresh FileTree to reflect changes instantly without reload
    ref
        .read(fileTreeProvider.notifier)
        .updateEncryptionKey(workspaceId, encryptedWorkspaceKey);
  }

  /// Gets the unwrapped Workspace Key for a workspace
  Future<List<int>> getWorkspaceKey() async {
    final workspaceNode = ref.read(workspaceNodeProvider);
    if (workspaceNode == null) {
      throw Exception("No workspace selected");
    }

    final encryptedKey = workspaceNode.folderConfig.encryptedKey;
    if (encryptedKey == null) {
      throw Exception("Encryption not enabled for this workspace");
    }

    final masterKey = await getMasterKeyAsync();
    return await _encryptionService.unwrapKey(encryptedKey, masterKey);
  }

  /// Encrypts data for a specific workspace
  Future<String> encryptData(String plaintext) async {
    final key = await getWorkspaceKey();
    return await _encryptionService.encrypt(plaintext, key);
  }

  /// Decrypts data for a specific workspace
  Future<String> decryptData(String ciphertext) async {
    try {
      final key = await getWorkspaceKey();
      return await _encryptionService.decrypt(ciphertext, key);
    } catch (err) {
      debugPrint("error: ${err.toString()}");
      throw Exception("Failed to decrypt data");
    }
  }
}

import 'dart:async';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/repository/storage_repository.dart';
import 'package:flutter/material.dart';

class FolderEditorController extends ChangeNotifier {
  // --- STATE ---
  FolderNode _currentNode;
  final StorageRepository _repo;
  final Function(FolderNode) onSaveToRepo;

  // Runtime Calculated Data
  bool isLoading = true;
  List<KeyValueItem> inheritedHeaders = [];
  AuthData effectiveAuth = const AuthData();
  String effectiveAuthSource = "None";

  Timer? _debounceTimer;

  FolderEditorController({
    required FolderNode node,
    required StorageRepository repo,
    required this.onSaveToRepo,
  }) : _currentNode = node,
       _repo = repo {
    _initData();
  }

  FolderNode get node => _currentNode;

  // --- INITIALIZATION ---
  Future<void> _initData() async {
    isLoading = true;
    notifyListeners();

    try {
      // 1. Hydrate Current Node (In-Place)
      if (!_currentNode.folderConfig.isDetailLoaded) {
        final details = await _repo.getNodeDetails(_currentNode.id);
        if (details.isNotEmpty) {
          // This updates _currentNode.config internally
          _currentNode.hydrate(details);
        }
      }

      // 2. Hydrate Parent Chain
      // We assume parents are linked via .parent. We walk up and ensure they are loaded.
      Node? ptr = _currentNode.parent;
      while (ptr != null) {
        if (!ptr.config.isDetailLoaded) {
          debugPrint("Hydrating ancestor: ${ptr.name}...");
          final details = await _repo.getNodeDetails(ptr.id);
          if (details.isNotEmpty) {
            ptr.hydrate(details); // Updates the parent object in-place!
          }
        }
        ptr = ptr.parent;
      }

      // 3. Calculate Inheritance (Safe now that chain is hydrated)
      _calculateInheritance();
    } catch (e) {
      debugPrint("Error initializing folder editor: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _calculateInheritance() {
    // 1. Headers Inheritance
    inheritedHeaders = [];
    Node? ptr = _currentNode.parent;

    while (ptr != null) {
      // Access headers via .config
      final parentHeaders = ptr.config.headers;
      // Insert parent headers at the top
      inheritedHeaders.insertAll(0, parentHeaders.where((h) => h.isEnabled));
      ptr = ptr.parent;
    }

    // 2. Auth Inheritance
    _resolveAuth();

    // Notify UI (e.g. to redraw inherited lists)
    notifyListeners();
  }

  void _resolveAuth() {
    final currentAuth = _currentNode.folderConfig.auth;

    // Case 1: Explicit Auth
    if (currentAuth.type != AuthType.inherit) {
      effectiveAuth = currentAuth;
      effectiveAuthSource = "This Folder";
      return;
    }

    // Case 2: Walk the chain
    Node? ptr = _currentNode.parent;
    while (ptr != null) {
      final pAuth = ptr.config.auth;

      if (pAuth.type == AuthType.noAuth) {
        effectiveAuth = const AuthData(type: AuthType.noAuth);
        effectiveAuthSource = "Blocked by ${ptr.name}";
        return;
      }

      if (pAuth.type != AuthType.inherit) {
        effectiveAuth = pAuth;
        effectiveAuthSource = "Inherited from ${ptr.name}";
        return;
      }
      ptr = ptr.parent;
    }

    // Case 3: Root reached
    effectiveAuth = const AuthData(type: AuthType.noAuth);
    effectiveAuthSource = "No Auth Configured";
  }

  // --- MUTATORS & SAVING ---

  void _triggerSave() {
    notifyListeners(); // Update UI immediately
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      debugPrint("Auto-saving ${_currentNode.name}...");
      onSaveToRepo(_currentNode);
    });
  }

  // 1. Rename (Requires copyWith because 'name' is final on Node shell)
  void updateName(String val) {
    // We create a new Shell, but it shares the SAME config object reference
    _currentNode = _currentNode.copyWith(name: val) as FolderNode;
    _triggerSave();
  }

  // 2. Update Description (Mutable Config)
  void updateDescription(String val) {
    _currentNode.folderConfig.description = val;
    _triggerSave();
  }

  // 3. Update Headers (Mutable Config)
  void updateHeaders(List<KeyValueItem> newHeaders) {
    _currentNode.folderConfig.headers = newHeaders;
    _triggerSave();
  }

  // 4. Update Variables (Mutable Config)
  void updateVariables(List<KeyValueItem> newVars) {
    _currentNode.folderConfig.variables = newVars;
    _triggerSave();
  }

  // 5. Update Auth (Mutable Config)
  void updateAuth(AuthData newAuth) {
    _currentNode.folderConfig.auth = newAuth;

    // If switching TO inherit, we need to recalculate what we are inheriting from
    if (newAuth.type == AuthType.inherit) {
      _calculateInheritance();
    } else {
      // Just update the effective display locally
      _resolveAuth();
      notifyListeners();
    }

    _triggerSave();
  }
}

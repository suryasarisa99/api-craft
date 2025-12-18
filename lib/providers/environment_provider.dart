import 'package:api_craft/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/models/models.dart';
import 'package:uuid/uuid.dart';

class EnvironmentState {
  final List<Environment> environments;
  final List<CookieJarModel> cookieJars;
  final String? selectedEnvironmentId;
  final String? selectedCookieJarId;
  final bool isLoading;

  EnvironmentState({
    this.environments = const [],
    this.cookieJars = const [],
    this.selectedEnvironmentId,
    this.selectedCookieJarId,
    this.isLoading = true,
  });

  Environment? get selectedEnvironment {
    if (selectedEnvironmentId == null) return null;
    try {
      return environments.firstWhere((e) => e.id == selectedEnvironmentId);
    } catch (_) {
      return null;
    }
  }

  CookieJarModel? get selectedCookieJar {
    if (selectedCookieJarId == null) return null;
    try {
      return cookieJars.firstWhere((e) => e.id == selectedCookieJarId);
    } catch (_) {
      return null;
    }
  }

  EnvironmentState copyWith({
    List<Environment>? environments,
    List<CookieJarModel>? cookieJars,
    String? selectedEnvironmentId,
    String? selectedCookieJarId,
    bool? isLoading,
  }) {
    return EnvironmentState(
      environments: environments ?? this.environments,
      cookieJars: cookieJars ?? this.cookieJars,
      selectedEnvironmentId:
          selectedEnvironmentId ?? this.selectedEnvironmentId,
      selectedCookieJarId: selectedCookieJarId ?? this.selectedCookieJarId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class EnvironmentNotifier extends Notifier<EnvironmentState> {
  final Uuid _uuid = const Uuid();

  @override
  EnvironmentState build() {
    final collection = ref.watch(selectedCollectionProvider);
    if (collection != null) {
      Future.microtask(() => loadData(collection.id));
      return EnvironmentState(isLoading: true);
    }
    return EnvironmentState(isLoading: false);
  }

  Future<void> loadData(String collectionId) async {
    state = state.copyWith(isLoading: true);
    await ref.read(databaseProvider);
    debugPrint("env::load-data $collectionId");
    final repo = ref.read(repositoryProvider);

    try {
      var envs = await repo.getEnvironments(collectionId);
      var jars = await repo.getCookieJars(collectionId);

      // Ensure defaults
      if (envs.isEmpty) {
        final defaultEnv = Environment(
          id: _uuid.v4(),
          collectionId: collectionId,
          name: 'Default',
          color: null,
        );
        await repo.createEnvironment(defaultEnv);
        envs = [defaultEnv];
      }

      if (jars.isEmpty) {
        final defaultJar = CookieJarModel(
          id: _uuid.v4(),
          collectionId: collectionId,
          name: 'Default',
        );
        await repo.createCookieJar(defaultJar);
        jars = [defaultJar];
      }

      // Keep selection or select first/default
      String? selEnv = state.selectedEnvironmentId;
      if (selEnv == null || !envs.any((e) => e.id == selEnv)) {
        selEnv = envs.isNotEmpty ? envs.first.id : null;
      }

      String? selJar = state.selectedCookieJarId;
      if (selJar == null || !jars.any((e) => e.id == selJar)) {
        selJar = jars.isNotEmpty ? jars.first.id : null;
      }

      state = state.copyWith(
        environments: envs,
        cookieJars: jars,
        selectedEnvironmentId: selEnv,
        selectedCookieJarId: selJar,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("EnvironmentProvider loading error: $e");
      state = state.copyWith(
        isLoading: false,
        environments: [],
        cookieJars: [],
      );
    }
  }

  void selectEnvironment(String id) {
    state = state.copyWith(selectedEnvironmentId: id);
  }

  void selectCookieJar(String id) {
    state = state.copyWith(selectedCookieJarId: id);
  }

  Future<void> createEnvironment(
    String name,
    String collectionId, {
    Color? color,
    bool isShared = false,
  }) async {
    final repo = ref.read(repositoryProvider);
    final newEnv = Environment(
      id: _uuid.v4(),
      collectionId: collectionId,
      name: name,
      color: color,
      isShared: isShared,
    );
    await repo.createEnvironment(newEnv);
    await loadData(collectionId);
    selectEnvironment(newEnv.id);
  }

  Future<void> updateEnvironment(Environment env) async {
    final repo = ref.read(repositoryProvider);
    await repo.updateEnvironment(env);
    await loadData(env.collectionId);
  }

  Future<void> duplicateEnvironment(Environment env) async {
    final newEnv = env.copyWith(id: _uuid.v4(), name: "${env.name} (Copy)");
    final repo = ref.read(repositoryProvider);
    await repo.createEnvironment(newEnv);
    await loadData(env.collectionId);
  }

  Future<void> toggleShared(Environment env) async {
    final updated = env.copyWith(isShared: !env.isShared);
    await updateEnvironment(updated);
  }

  Future<void> deleteEnvironment(String id) async {
    final curEnv = state.selectedEnvironment;
    final repo = ref.read(repositoryProvider);
    await repo.deleteEnvironment(id);

    if (curEnv?.id == id) {
      state = state.copyWith(selectedEnvironmentId: null);
    }
    // Reload
    final collectionId = state.environments
        .firstWhere((e) => e.id == id)
        .collectionId;
    await loadData(collectionId);
  }

  Future<void> updateCookieJar(CookieJarModel jar) async {
    final repo = ref.read(repositoryProvider);
    await repo.updateCookieJar(jar);
    await loadData(jar.collectionId);
  }

  Future<void> createCookieJar(String name, String collectionId) async {
    final repo = ref.read(repositoryProvider);
    final newJar = CookieJarModel(
      id: _uuid.v4(),
      collectionId: collectionId,
      name: name,
    );
    await repo.createCookieJar(newJar);
    await loadData(collectionId);
    selectCookieJar(newJar.id);
  }

  Future<void> renameCookieJar(String id, String newName) async {
    final jar = state.cookieJars.firstWhere((j) => j.id == id);
    final updated = jar.copyWith(name: newName);
    await updateCookieJar(updated);
  }

  Future<void> saveCookiesToJar(
    String jarId,
    List<CookieDef> newCookies,
  ) async {
    final jar = state.cookieJars.firstWhere((j) => j.id == jarId);
    // Merge logic: replace existing cookies with same key/domain/path?
    // For simplicity, we'll iterate new cookies and upsert into existing list.
    // A proper cookie store is complex (domain matching etc), but here we store as list.

    // We need to match based on Key + Domain (and maybe Path).
    // Let's assume Key + Domain is unique enough for this simple list.

    final currentCookies = List<CookieDef>.from(jar.cookies);

    for (final nc in newCookies) {
      // Find index of existing cookie
      final idx = currentCookies.indexWhere(
        (c) =>
            c.key == nc.key &&
            c.domain == nc.domain &&
            c.path == nc.path, // Strict match?
        // Usually domain/path in Set-Cookie might be absent (meaning host/path of req).
        // The nc passed here should have domain/path filled from request context if missing?
        // We will handle that in caller.
      );

      if (idx != -1) {
        currentCookies[idx] = nc;
      } else {
        currentCookies.add(nc);
      }
    }

    final updatedJar = jar.copyWith(cookies: currentCookies);
    await updateCookieJar(updatedJar);
  }
}

final environmentProvider =
    NotifierProvider<EnvironmentNotifier, EnvironmentState>(
      EnvironmentNotifier.new,
    );

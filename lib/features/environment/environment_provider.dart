import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
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

  /// The currently selected sub-environment.
  /// Note: The Global environment is always effective implicitly in the Resolver.
  Environment? get selectedEnvironment {
    if (selectedEnvironmentId == null) return null;
    try {
      return environments.firstWhere((e) => e.id == selectedEnvironmentId);
    } catch (_) {
      return null;
    }
  }

  Environment? get globalEnvironment {
    try {
      return environments.firstWhere((e) => e.isGlobal);
    } catch (_) {
      return null;
    }
  }

  List<Environment> get subEnvironments =>
      environments.where((e) => !e.isGlobal).toList();

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
    final collectionId = ref.watch(
      selectedCollectionProvider.select((c) => c?.id),
    );
    if (collectionId != null) {
      Future.microtask(() => loadData(collectionId));
      return EnvironmentState(isLoading: true);
    }
    return EnvironmentState(isLoading: false);
  }

  Future<void> loadData(String collectionId) async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(repositoryProvider);

    try {
      var envs = await repo.getEnvironments(collectionId);
      var jars = await repo.getCookieJars(collectionId);

      // Get persisted selection from the Collection Model
      final collection = ref.read(selectedCollectionProvider);

      String? selEnv = collection?.selectedEnvId;
      String? selJar = collection?.selectedJarId;

      // Validate Env persistence
      if (selEnv != null && !envs.any((e) => e.id == selEnv)) {
        selEnv = null;
      }

      // Validate Jar persistence
      if (selJar != null && !jars.any((e) => e.id == selJar)) {
        selJar = null;
      }

      // Default Jar if none selected?
      if (selJar == null && jars.isNotEmpty) {
        selJar = jars.first.id;
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

  void selectEnvironment(String? id) {
    state = state.copyWith(selectedEnvironmentId: id);
    _persistSelection();
  }

  void selectCookieJar(String id) {
    state = state.copyWith(selectedCookieJarId: id);
    _persistSelection();
  }

  Future<void> _persistSelection() async {
    final collection = ref.read(selectedCollectionProvider);
    if (collection != null) {
      // 1. Update Provider State
      final updatedCol = collection.copyWith(
        selectedEnvId: state.selectedEnvironmentId,
        selectedJarId: state.selectedCookieJarId,
      );
      ref.read(selectedCollectionProvider.notifier).select(updatedCol);

      // 2. Update DB
      final repo = ref.read(repositoryProvider);
      repo.updateCollectionSelection(
        collection.id,
        state.selectedEnvironmentId,
        state.selectedCookieJarId,
      );
    }
  }

  Future<void> createEnvironment(
    String name,
    String collectionId, {
    Color? color,
    bool isShared = false,
    bool isGlobal = false,
  }) async {
    final repo = ref.read(repositoryProvider);
    final newEnv = Environment(
      id: _uuid.v4(),
      collectionId: collectionId,
      name: name,
      color: color,
      isShared: isShared,
      isGlobal: isGlobal,
    );

    // Update local state
    state = state.copyWith(environments: [...state.environments, newEnv]);

    if (!isGlobal) {
      selectEnvironment(newEnv.id);
    }
    repo.createEnvironment(newEnv);
  }

  Future<void> updateEnvironment(Environment env) async {
    final repo = ref.read(repositoryProvider);

    // Update local state
    final index = state.environments.indexWhere((e) => e.id == env.id);
    if (index != -1) {
      final newEnvs = List<Environment>.from(state.environments);
      newEnvs[index] = env;
      state = state.copyWith(environments: newEnvs);
    }

    await repo.updateEnvironment(env);
  }

  Future<void> duplicateEnvironment(Environment env) async {
    if (env.isGlobal) return;

    final newEnv = env.copyWith(
      id: _uuid.v4(),
      name: "${env.name} (Copy)",
      isGlobal: false,
    );
    final repo = ref.read(repositoryProvider);

    state = state.copyWith(environments: [...state.environments, newEnv]);

    await repo.createEnvironment(newEnv);
  }

  Future<void> toggleShared(Environment env) async {
    final updated = env.copyWith(isShared: !env.isShared);
    await updateEnvironment(updated);
  }

  Future<void> deleteEnvironment(String id) async {
    final target = state.environments.firstWhere((e) => e.id == id);
    if (target.isGlobal) return;

    final curEnvId = state.selectedEnvironmentId;
    final repo = ref.read(repositoryProvider);

    // Update state first
    state = state.copyWith(
      environments: state.environments.where((e) => e.id != id).toList(),
    );

    await repo.deleteEnvironment(id);

    if (curEnvId == id) {
      state = state.copyWith(selectedEnvironmentId: null);
      _persistSelection();
    }
  }

  Future<void> updateCookieJar(CookieJarModel jar) async {
    final repo = ref.read(repositoryProvider);

    final index = state.cookieJars.indexWhere((j) => j.id == jar.id);
    if (index != -1) {
      final newJars = List<CookieJarModel>.from(state.cookieJars);
      newJars[index] = jar;
      state = state.copyWith(cookieJars: newJars);
    }

    await repo.updateCookieJar(jar);
  }

  Future<void> createCookieJar(String name, String collectionId) async {
    final repo = ref.read(repositoryProvider);
    final newJar = CookieJarModel(
      id: _uuid.v4(),
      collectionId: collectionId,
      name: name,
    );

    state = state.copyWith(cookieJars: [...state.cookieJars, newJar]);

    await repo.createCookieJar(newJar);
    selectCookieJar(newJar.id);
  }

  Future<void> renameCookieJar(String id, String newName) async {
    final jar = state.cookieJars.firstWhere((j) => j.id == id);
    final updated = jar.copyWith(name: newName);
    await updateCookieJar(updated);
  }

  Future<void> deleteCookieJar(String id) async {
    final repo = ref.read(repositoryProvider);

    state = state.copyWith(
      cookieJars: state.cookieJars.where((j) => j.id != id).toList(),
    );

    await repo.deleteCookieJar(id);

    if (state.selectedCookieJarId == id) {
      state = state.copyWith(selectedCookieJarId: null);
      _persistSelection();
    }
  }

  Future<void> saveCookiesToJar(
    String jarId,
    List<CookieDef> newCookies,
  ) async {
    final jar = state.cookieJars.firstWhere((j) => j.id == jarId);

    final currentCookies = List<CookieDef>.from(jar.cookies);

    for (final nc in newCookies) {
      final idx = currentCookies.indexWhere(
        (c) => c.key == nc.key && c.domain == nc.domain && c.path == nc.path,
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

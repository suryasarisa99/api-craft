import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnvService {
  static String? getVariable(Ref ref, String key) {
    final envState = ref.read(environmentProvider);
    final selectedEnv = envState.selectedEnvironment;
    if (selectedEnv == null) return null;

    final v = selectedEnv.variables.where((v) => v.key == key).firstOrNull;
    return v?.value;
  }

  static void setVariable(
    Ref ref, {
    required String key,
    required String value,
  }) {
    final envState = ref.read(environmentProvider);
    final selectedEnv =
        envState.selectedEnvironment ?? envState.globalEnvironment;
    if (selectedEnv == null) return;

    final updatedVars = List<KeyValueItem>.from(selectedEnv.variables);
    final index = updatedVars.indexWhere((v) => v.key == key);

    if (index != -1) {
      updatedVars[index] = updatedVars[index].copyWith(value: value);
    } else {
      updatedVars.add(KeyValueItem(key: key, value: value));
    }

    ref
        .read(environmentProvider.notifier)
        .updateEnvironment(selectedEnv.copyWith(variables: updatedVars));
  }

  // 1 means direct parent
  // 2 means grand parent
  // 3 means great grand parent,so on
  void setFolderVariable(
    Ref ref, {
    required String key,
    required String value,
    required String requestId,
    int parent = 1,
  }) {
    final parentId = getParentId(ref, requestId, parent);
    if (parentId == null) return;
    final parentNode = ref.read(fileTreeProvider).nodeMap[parentId];
    // if hydrated,update db,update state.
    // if not hydrated,hydrate node,update db,{update state.}
  }

  String? getParentId(Ref ref, String requestId, int parent) {
    //loop to get parent
    var cur = ref.read(fileTreeProvider).nodeMap[requestId];
    while (parent > 0 && cur != null && cur.parentId != null) {
      cur = ref.read(fileTreeProvider).nodeMap[cur.parentId];
      parent--;
    }
    return cur?.id;
  }
}

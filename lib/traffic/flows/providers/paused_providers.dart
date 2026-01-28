import 'package:flutter_riverpod/flutter_riverpod.dart';

final pausedFlowsProvider =
    NotifierProvider<PausedFlowsNotifier, Map<String, String>>(
      PausedFlowsNotifier.new,
    );

class PausedFlowsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    return {};
  }

  void add(String id, String type) {
    state = {...state, id: type};
  }

  void remove(String id) {
    state.remove(id);
    state = {...state};
  }

  String? get(String id) {
    return state[id];
  }
}

// Instead of state being a single Node?, make it a Set<String>
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectionNodesNotifier extends Notifier<Set<String>> {
  @override
  build() => {};

  void select(String path, {bool multi = false}) {
    if (multi) {
      state = {...state, path}; // Add to selection
    } else {
      state = {path}; // Clear others, select this
    }
  }

  void toggle(String path) {
    if (state.contains(path)) {
      state = state.where((p) => p != path).toSet();
    } else {
      state = {...state, path};
    }
  }

  bool isSelected(String path) => state.contains(path);

  void clear() {
    state = {};
  }
}

final selectedNodesProvider =
    NotifierProvider<SelectionNodesNotifier, Set<String>>(
      () => SelectionNodesNotifier(),
    );

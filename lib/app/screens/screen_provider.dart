import 'package:flutter_riverpod/flutter_riverpod.dart';

final screenProvider = NotifierProvider<ScreenNotifier, int>(
  ScreenNotifier.new,
);

class ScreenNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void set(int index) {
    state = index;
  }

  void toggle() {
    state = state == 0 ? 1 : 0;
  }
}

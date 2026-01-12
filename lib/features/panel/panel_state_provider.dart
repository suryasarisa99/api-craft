import 'package:flutter_riverpod/flutter_riverpod.dart';

class PanelState {
  final int activeIndex;
  final bool isMaximized;

  const PanelState({this.activeIndex = 0, this.isMaximized = false});

  PanelState copyWith({int? activeIndex, bool? isMaximized}) {
    return PanelState(
      activeIndex: activeIndex ?? this.activeIndex,
      isMaximized: isMaximized ?? this.isMaximized,
    );
  }
}

final panelStateProvider = NotifierProvider<PanelStateNotifier, PanelState>(
  PanelStateNotifier.new,
);

class PanelStateNotifier extends Notifier<PanelState> {
  @override
  PanelState build() {
    return const PanelState();
  }

  void setIndex(int index) {
    state = state.copyWith(activeIndex: index);
  }

  void toggleMaximized() {
    state = state.copyWith(isMaximized: !state.isMaximized);
  }

  void setMaximized(bool value) {
    state = state.copyWith(isMaximized: value);
  }
}

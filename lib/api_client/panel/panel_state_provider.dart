import 'package:flutter_riverpod/flutter_riverpod.dart';

class PanelState {
  final int activeIndex;
  final bool isMaximized;
  final int layoutVersion; // Version counter to trigger explicit layout changes

  const PanelState({
    this.activeIndex = 0,
    this.isMaximized = false,
    this.layoutVersion = 0,
  });

  PanelState copyWith({
    int? activeIndex,
    bool? isMaximized,
    int? layoutVersion,
  }) {
    return PanelState(
      activeIndex: activeIndex ?? this.activeIndex,
      isMaximized: isMaximized ?? this.isMaximized,
      layoutVersion: layoutVersion ?? this.layoutVersion,
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
    // Default to true forceLayout for toggle (usually button)
    setMaximized(!state.isMaximized, forceLayout: true);
  }

  void setMaximized(bool value, {bool forceLayout = false}) {
    state = state.copyWith(
      isMaximized: value,
      layoutVersion: forceLayout ? state.layoutVersion + 1 : null,
    );
  }
}

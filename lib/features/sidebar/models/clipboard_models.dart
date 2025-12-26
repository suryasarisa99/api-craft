enum ClipboardAction { copy, cut }

class ClipboardState {
  final Set<String> nodeIds;
  final ClipboardAction action;

  const ClipboardState({
    required this.nodeIds,
    this.action = ClipboardAction.copy,
  });

  bool get isEmpty => nodeIds.isEmpty;
  bool get isNotEmpty => nodeIds.isNotEmpty;
}

import 'dart:async';
import 'dart:ui';

class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer([this.duration = const Duration(milliseconds: 300)]);

  /// Run the given action after the debounce [duration].
  /// If run is called again before [duration] elapses, the previous
  /// pending action is cancelled.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancel any pending action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

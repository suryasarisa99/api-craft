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

class DebouncerFlush {
  final Duration duration;
  Timer? _timer;
  VoidCallback? _action;

  DebouncerFlush([this.duration = const Duration(milliseconds: 300)]);

  void run(VoidCallback action) {
    _action = action;
    _timer?.cancel();
    _timer = Timer(duration, () {
      _action?.call();
      _action = null;
    });
  }

  /// Runs pending action immediately
  void flush() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      _action?.call();
      _action = null;
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _action = null;
  }

  void dispose() => cancel();
}

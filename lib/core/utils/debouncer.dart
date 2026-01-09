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

class GroupedDebouncer {
  final Duration duration;
  final Map<String, Timer> _timers = {};
  final Map<String, VoidCallback> _actions = {};

  GroupedDebouncer([this.duration = const Duration(milliseconds: 300)]);

  void run(String id, VoidCallback action) {
    _actions[id] = action;
    _timers[id]?.cancel();
    _timers[id] = Timer(duration, () {
      _actions[id]?.call();
      _actions.remove(id);
      _timers.remove(id);
    });
  }

  void flush(String id) {
    if (_timers.containsKey(id)) {
      _timers[id]!.cancel();
      _timers.remove(id);
      _actions[id]?.call();
      _actions.remove(id);
    }
  }

  void cancel(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    _actions.remove(id);
  }

  void flushAll() {
    final ids = List<String>.from(_timers.keys);
    for (var id in ids) {
      flush(id);
    }
  }

  void cancelAll() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _actions.clear();
  }

  void dispose() => cancelAll();
}

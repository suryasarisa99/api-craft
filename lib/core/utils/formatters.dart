/// Formats a duration in milliseconds to a human-readable string.
/// - If < 1000ms, returns "X ms"
/// - If >= 1000ms, returns "X.XX s"
String formatDuration(int ms) {
  if (ms < 1000) {
    return "$ms ms";
  } else {
    final seconds = ms / 1000;
    // Remove trailing zeros/dot if integer
    if (seconds == seconds.truncateToDouble()) {
      return "${seconds.toInt()} s";
    }
    return "${seconds.toStringAsFixed(2)} s";
  }
}

enum ConsoleLogLevel { log, debug, info, warning, error }

enum ConsoleLogSource { system, javascript, network }

class ConsoleLogEntry {
  final DateTime timestamp;
  final ConsoleLogLevel level;
  final ConsoleLogSource source;
  final List<dynamic> args;

  ConsoleLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.args,
  });

  factory ConsoleLogEntry.log(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    return ConsoleLogEntry(
      timestamp: DateTime.now(),
      level: ConsoleLogLevel.log,
      source: source,
      args: (message is List) ? message : [message],
    );
  }

  factory ConsoleLogEntry.debug(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    return ConsoleLogEntry(
      timestamp: DateTime.now(),
      level: ConsoleLogLevel.debug,
      source: source,
      args: (message is List) ? message : [message],
    );
  }

  factory ConsoleLogEntry.info(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    return ConsoleLogEntry(
      timestamp: DateTime.now(),
      level: ConsoleLogLevel.info,
      source: source,
      args: (message is List) ? message : [message],
    );
  }

  factory ConsoleLogEntry.warn(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    return ConsoleLogEntry(
      timestamp: DateTime.now(),
      level: ConsoleLogLevel.warning,
      source: source,
      args: (message is List) ? message : [message],
    );
  }

  factory ConsoleLogEntry.error(
    dynamic message, {
    dynamic details,
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    final List<dynamic> argList = (message is List) ? [...message] : [message];
    if (details != null) {
      argList.add(details);
    }
    return ConsoleLogEntry(
      timestamp: DateTime.now(),
      level: ConsoleLogLevel.error,
      source: source,
      args: argList,
    );
  }
}

import 'package:api_craft/features/console/models/console_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final consoleLogsProvider =
    NotifierProvider<ConsoleLogsNotifier, List<ConsoleLogEntry>>(
      ConsoleLogsNotifier.new,
    );

class ConsoleLogsNotifier extends Notifier<List<ConsoleLogEntry>> {
  @override
  List<ConsoleLogEntry> build() {
    return [];
  }

  void log(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    state = [...state, ConsoleLogEntry.log(message, source: source)];
  }

  void debug(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    state = [...state, ConsoleLogEntry.debug(message, source: source)];
  }

  void info(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    state = [...state, ConsoleLogEntry.info(message, source: source)];
  }

  void error(
    dynamic message, {
    dynamic details,
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    state = [
      ...state,
      ConsoleLogEntry.error(message, details: details, source: source),
    ];
  }

  void warn(
    dynamic message, {
    ConsoleLogSource source = ConsoleLogSource.system,
  }) {
    state = [...state, ConsoleLogEntry.warn(message, source: source)];
  }

  void add(ConsoleLogEntry entry) {
    state = [...state, entry];
  }

  void clear() {
    state = [];
  }
}

import 'package:api_craft/features/console/models/console_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsoleFilterState {
  final String query;
  final Set<ConsoleLogLevel> activeLevels;

  const ConsoleFilterState({
    this.query = '',
    this.activeLevels = const {
      ConsoleLogLevel.log,
      ConsoleLogLevel.debug,
      ConsoleLogLevel.info,
      ConsoleLogLevel.warning,
      ConsoleLogLevel.error,
    },
  });

  ConsoleFilterState copyWith({
    String? query,
    Set<ConsoleLogLevel>? activeLevels,
  }) {
    return ConsoleFilterState(
      query: query ?? this.query,
      activeLevels: activeLevels ?? this.activeLevels,
    );
  }
}

final consoleFilterProvider =
    NotifierProvider<ConsoleFilterNotifier, ConsoleFilterState>(
      ConsoleFilterNotifier.new,
    );

class ConsoleFilterNotifier extends Notifier<ConsoleFilterState> {
  @override
  ConsoleFilterState build() {
    return const ConsoleFilterState();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void toggleLevel(ConsoleLogLevel level) {
    final newLevels = Set<ConsoleLogLevel>.from(state.activeLevels);
    if (newLevels.contains(level)) {
      newLevels.remove(level);
    } else {
      newLevels.add(level);
    }
    state = state.copyWith(activeLevels: newLevels);
  }

  void setLevels(Set<ConsoleLogLevel> levels) {
    state = state.copyWith(activeLevels: levels);
  }
}

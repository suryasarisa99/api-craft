import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockhttp/ui/rule_config.dart';

final interceptionProvider =
    NotifierProvider<InterceptionNotifier, List<ProxyRule>>(() {
      return InterceptionNotifier();
    });

class InterceptionNotifier extends Notifier<List<ProxyRule>> {
  @override
  List<ProxyRule> build() {
    // TODO: Load from SharedPreferences or disk db
    return [];
  }

  void addRule(ProxyRule rule) {
    state = [...state, rule];
  }

  void updateRule(int index, ProxyRule rule) {
    if (index >= 0 && index < state.length) {
      final newState = List<ProxyRule>.from(state);
      newState[index] = rule;
      state = newState;
    }
  }

  void removeRule(int index) {
    if (index >= 0 && index < state.length) {
      final newState = List<ProxyRule>.from(state);
      newState.removeAt(index);
      state = newState;
    }
  }

  void setRules(List<ProxyRule> rules) {
    state = List.from(rules);
  }
}

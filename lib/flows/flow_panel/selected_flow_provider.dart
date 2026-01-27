import 'package:api_craft/core/utils/parsers.dart';
import 'package:api_craft/flows/providers/flows_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedFlowIdProvider = NotifierProvider<SelectedFlowId, String?>(
  SelectedFlowId.new,
);

class SelectedFlowId extends Notifier<String?> {
  @override
  String? build() {
    return null;
  }

  void set(String? id) {
    state = id;
  }

  String? get() {
    return state;
  }

  void reset() {
    state = null;
  }
}

final flowProvider = Provider((ref) {
  final flowId = ref.watch(selectedFlowIdProvider);
  if (flowId == null) {
    return null;
  }
  return ref.watch((flowsProvider).select((flows) => flows[flowId]));
});

// provider for parser query params
final queryParamsProvider = Provider((ref) {
  final url = ref.watch(flowProvider.select((flow) => flow?.request?.url));
  return ParserUtils.parseQuery(url);
});

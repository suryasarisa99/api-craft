import 'package:api_craft/flows/models/flow.dart';
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
// class FlowNotifier extends Notifier<HttpFlow?> {
//   @override
//   HttpFlow? build() {
//     final flowId = ref.watch(selectedFlowIdProvider);
//     if (flowId == null) {
//       return null;
//     }
//     return ref.watch((flowsProvider).select((flows) => flows[flowId]));
//   }
// }

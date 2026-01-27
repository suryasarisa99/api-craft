import 'package:api_craft/flows/models/flow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final flowsProvider = NotifierProvider<FlowsNotifier, Map<String, HttpFlow>>(
  FlowsNotifier.new,
);

class FlowsNotifier extends Notifier<Map<String, HttpFlow>> {
  @override
  build() {
    return {};
  }

  void addFlow(HttpFlow flow) {
    // state = state..[flow.id] = flow;
    state = {...state, flow.id: flow};
  }

  void updateReq(FlowRequest req) {
    final id = req.id;
    final prv = state[id];
    if (prv == null) {
      addFlow(HttpFlow(id: id, request: req));
    } else {
      state = {...state, id: prv.updateReq(req)};
    }
  }

  void updateRes(FlowResponse res) {
    final id = res.id;
    final prv = state[id];
    if (prv == null) {
      addFlow(HttpFlow(id: id, response: res));
    } else {
      state = {...state, id: prv.updateRes(res)};
    }
  }

  void editReq(FlowRequest req) {
    final id = req.id;
    state = {...state, id: state[id]!.editReq(req)};
  }

  void editRes(FlowResponse res) {
    final id = res.id;
    state = {...state, id: state[id]!.editRes(res)};
  }

  void deleteFlows(Iterable<String> ids) {
    state.removeWhere((k, v) => ids.contains(k));
    state = {...state};
  }

  void revertChanges(Iterable<String> ids) {
    for (final id in ids) {
      state[id] = state[id]!.reset();
    }
    state = {...state};
  }

  void duplicateFlows(Iterable<String> ids) {
    final Map<String, HttpFlow> duplicated = {};
    for (final id in ids) {
      final flow = state[id]!.duplicate();
      duplicated[flow.id] = flow;
    }
    state = {...state, ...duplicated};
  }
}

class FlowIdList extends Notifier<List<String>> {
  @override
  build() {
    return [];
  }

  void addFlowId(String id) {
    state = [...state, id];
  }
}

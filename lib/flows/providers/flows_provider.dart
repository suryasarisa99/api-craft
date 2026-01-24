import 'package:api_craft/flows/models/flow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockhttp/types.dart';
import 'package:mockhttp/types/ongoing.dart';

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

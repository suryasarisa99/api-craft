import 'package:api_craft/flows/flow_panel/req_res_panel/edit_views.dart';
import 'package:api_craft/flows/flow_panel/req_res_panel/panel_abstract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReqPanelTitles extends AbstractPanelTitles {
  const ReqPanelTitles({super.key, required super.tabController});

  @override
  List<String> buildTabLabels(WidgetRef ref) {
    // final headerCount = ref.watch(
    //   headersProvider(id).select((l) => l?.length ?? 0),
    // );
    // final queryCount = ref.watch(
    //   parsedQueryProvider(id).select((l) => l.length),
    // );
    // final cookieCount = ref.watch(
    //   parsedCookiesProvider(id).select((l) => l.length),
    // );

    // return [
    //   "Headers ($headerCount)",
    //   "Query ($queryCount)",
    //   "Cookies ($cookieCount)",
    //   "Body",
    //   "Raw",
    // ];
    return ["Headers", "Query", "Cookies", "Body", "Raw"];
  }
}

class RequestPanel extends PanelAbstract {
  const RequestPanel({required super.resizeController, super.key});

  @override
  PanelAbstractState createState() => _RequestPanelState();
}

class _RequestPanelState extends PanelAbstractState {
  @override
  get tabsLen => 5;

  @override
  get title => "request";

  @override
  get panelTitles => ReqPanelTitles(tabController: tabController);

  // @override
  // int get previewBodyTabIndex => 3; // Preview body is at index 3

  @override
  List<Widget> buildViews() {
    return [
      EditHeadersView(),
      EditQueryParamsView(),
      ReadOnlyCookiesView(),
      Text("----"),
      Text("----"),
    ];
  }
}

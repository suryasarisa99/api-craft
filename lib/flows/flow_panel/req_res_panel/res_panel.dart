import 'package:api_craft/flows/flow_panel/req_res_panel/edit_views.dart';
import 'package:api_craft/flows/flow_panel/req_res_panel/panel_abstract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResPanelTitles extends AbstractPanelTitles {
  const ResPanelTitles({super.key, required super.tabController});

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
    return ["Headers", "Cookies", "Body", "Raw"];
  }
}

class ResponsePanel extends PanelAbstract {
  const ResponsePanel({required super.resizeController, super.key});

  @override
  PanelAbstractState createState() => _RequestPanelState();
}

class _RequestPanelState extends PanelAbstractState {
  @override
  get tabsLen => 4;

  @override
  get title => "response";

  @override
  get panelTitles => ResPanelTitles(tabController: tabController);

  // @override
  // int get previewBodyTabIndex => 3; // Preview body is at index 3

  @override
  List<Widget> buildViews() {
    return [
      EditResHeadersView(),
      ReadOnlySetCookiesView(),
      Text("Query Params"),
      Text("Query Params"),
      // ReqHeadersView(
      //   id: widget.id,
      //   title: "Headers",
      //   keyValueJoiner: ":",
      //   linesJoiner: "\n",
      // ),
      // EditHeadersView(id: widget.id),
      // QueryView(
      //   id: widget.id,
      //   title: "Query",
      //   keyValueJoiner: "=",
      //   linesJoiner: "&",
      // ),
      // EditQueryParams(id: widget.id),
      // CookiesView(
      //   id: widget.id,
      //   title: "Cookies",
      //   keyValueJoiner: "=",
      //   linesJoiner: "; ",
      // ),
    ];
  }
}

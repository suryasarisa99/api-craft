import 'package:api_craft/core/widgets/ui/top_bar.dart';
import 'package:api_craft/features/panel/status_bar.dart';
import 'package:api_craft/flows/flows_provider.dart';
import 'package:api_craft/flows/widgets/flows_list.dart';
import 'package:api_craft/flows/server_provider.dart';
import 'package:api_craft/packages/dt_table/dt_table.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlowsScreen extends ConsumerStatefulWidget {
  const FlowsScreen({super.key});

  @override
  ConsumerState<FlowsScreen> createState() => _FlowListScreenState();
}

class _FlowListScreenState extends ConsumerState<FlowsScreen> {
  // Single data source for all flows

  // Controller for the data grid to track selection and highlighting
  final _dtController = DtController();

  final flowId = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    ref.read(serverProvider);

    // _dtController.addSpecificListener(_flowIdListener);
  }

  @override
  void dispose() {
    _dtController.removeSpecificListener();
    super.dispose();
  }

  void launchInterceptorDialog() {}

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(body: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        TopBar(left: [], right: []),
        Expanded(child: FlowList(controller: _dtController)),
        StatusBar(),
      ],
    );
  }
}

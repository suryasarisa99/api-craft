import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/widgets/ui/key_value_editor.dart';
import 'package:api_craft/flows/flow_panel/selected_flow_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoid/nanoid.dart';

class EditHeadersView extends ConsumerStatefulWidget {
  const EditHeadersView({super.key});

  @override
  ConsumerState<EditHeadersView> createState() => _EditHeadersViewState();
}

class _EditHeadersViewState extends ConsumerState<EditHeadersView> {
  List<List<String>> _items = [];
  List<bool> _enabledItems = [];

  @override
  void initState() {
    super.initState();
    // _items = ref.read(headersProvider(widget.id)) ?? [];
    // _enabledItems =
    //     ref.read(flowProvider(widget.id))?.request?.enabledHeaders ??
    //     List.filled(_items.length, true, growable: true);
  }

  // List<List<String>> filterItems() {
  //   // // return _items.where((item) => item[0].isNotEmpty).toList();
  //   // return [
  //   //   for (var (i, item) in _items.indexed)
  //   //     if (_enabledItems[i] && item[0].isNotEmpty) item,
  //   // ];
  // }

  void updateClient() {
    // MitmproxyClient.updateHeaders(widget.id, filterItems());
  }

  void onItemChanged(int index, String key, String value) {
    // _items[index] = [key, value];
    // _enabledItems[index] = true;
    // // if (index >= _enabledItems.length) {
    // //   _enabledItems.add(true);
    // // } else {
    // // }
    // updateClient();
  }

  void onItemToggled(int index, bool enabled) {
    // if (ref.read(flowProvider(widget.id))!.request!.enabledHeaders == null) {
    //   ref.flowsN.updateEnabledHeaders(widget.id, _enabledItems);
    //   _enabledItems = ref.flows[widget.id]!.request!.enabledHeaders!;
    // }
    // _enabledItems[index] = enabled;
    // setState(() {});
    // updateClient();
  }

  @override
  Widget build(BuildContext context) {
    // final headers = ref.watch(headersProvider(widget.id));

    // return InputsView(
    //   title: "Headers",
    //   id: widget.id,
    //   enabled: _enabledItems,
    //   items: _items,
    //   onItemToggled: onItemToggled,
    //   onItemReordered: (a, b) {},
    //   onItemChanged: onItemChanged,
    //   onItemAdded: (a, b) {},
    //   keyValueJoiner: ':',
    //   linesJoiner: '\n',
    // );

    final id = ref.watch(selectedFlowIdProvider);

    final headers = ref.watch(
      flowProvider.select((s) => s?.request?.headers ?? []),
    );

    return KeyValueEditor(
      items: headers
          .map(
            (e) => KeyValueItem(
              id: nanoid(),
              isEnabled: true,
              key: e.first,
              value: e.last,
            ),
          )
          .toList(),
      onChanged: (_) {},
      id: id,
      mode: .headers,
    );
  }
}

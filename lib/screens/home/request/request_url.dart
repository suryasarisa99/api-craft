import 'package:api_craft/http/send_request.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/config_resolver_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/widgets/ui/variable_text_field_custom.dart';
import 'package:flutter/material.dart';

class RequestUrl extends ConsumerStatefulWidget {
  final String id;
  const RequestUrl({required this.id, super.key});

  @override
  ConsumerState<RequestUrl> createState() => _RequestUrlState();
}

class _RequestUrlState extends ConsumerState<RequestUrl> {
  late final TextEditingController _controller;
  late final notifier = ref.read(resolveConfigProvider(widget.id).notifier);
  @override
  void initState() {
    super.initState();
    final initialUrl =
        (ref.read(resolveConfigProvider(widget.id)).node as RequestNode).url;
    _controller = TextEditingController(text: initialUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // menu
        Consumer(
          builder: (context, ref, child) {
            final method = ref.watch(
              resolveConfigProvider(
                widget.id,
              ).select((d) => (d.node as RequestNode).method),
            );
            debugPrint("RequestUrl rebuild method: $method");
            return DropdownButton(
              value: method,
              isDense: true,
              items: [
                DropdownMenuItem(value: "GET", child: Text("GET")),
                DropdownMenuItem(value: "POST", child: Text("POST")),
                DropdownMenuItem(value: "PUT", child: Text("PUT")),
                DropdownMenuItem(value: "DELETE", child: Text("DELETE")),
                DropdownMenuItem(value: "PATCH", child: Text("PATCH")),
              ],
              onChanged: (v) {
                if (v != null) {
                  notifier.updateMethod(v);
                }
              },
            );
          },
        ),
        SizedBox(width: 8),

        Expanded(
          child: VariableTextFieldCustom(
            controller: _controller,
            onChanged: (v) {
              notifier.updateUrl(v);
            },
          ),
        ),
        SizedBox(width: 8),
        IconButton(
          onPressed: () {
            run(ref.read(resolveConfigProvider(widget.id)));
          },
          iconSize: 17,
          icon: Icon(Icons.send),
        ),
      ],
    );
  }
}

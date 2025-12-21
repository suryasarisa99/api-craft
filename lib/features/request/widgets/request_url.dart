import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/ref_provider.dart';
import 'package:api_craft/features/request/providers/req_compose_provider.dart';
import 'package:api_craft/core/services/app_service.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/widgets/ui/variable_text_field_custom.dart';
import 'package:flutter/material.dart';

class RequestUrl extends ConsumerStatefulWidget {
  final String id;
  const RequestUrl({required this.id, super.key});

  @override
  ConsumerState<RequestUrl> createState() => _RequestUrlState();
}

const methods = [
  "GET",
  "POST",
  "PUT",
  "DELETE",
  "PATCH",
  "OPTIONS",
  "HEAD",
  "Query",
  "CONNECT",
  "CUSTOM",
];
const Map<String, Color> methodsColorsMap = {
  "GET": Colors.green,
  "POST": Colors.blue,
  "PUT": Colors.orange,
  "DELETE": Colors.red,
  "PATCH": Colors.purple,
  "OPTIONS": Colors.teal,
  "HEAD": Colors.brown,
  "Query": Colors.indigo,
  "CONNECT": Colors.cyan,
  "CUSTOM": Colors.grey,
};

class _RequestUrlState extends ConsumerState<RequestUrl> {
  late final TextEditingController _controller;
  late final notifier = ref.read(reqComposeProvider(widget.id).notifier);
  final popupKey = GlobalKey<CustomPopupState>();
  @override
  void initState() {
    super.initState();
    final initialUrl =
        (ref.read(reqComposeProvider(widget.id)).node as RequestNode).url;
    _controller = TextEditingController(text: initialUrl);
  }

  void sendReq() async {
    final r = ref.read(refProvider);
    final response = await AppService.http.run(r, widget.id, context: context);
    debugPrint(
      "response received, adding to history, status: ${response.statusCode}",
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      reqComposeProvider(widget.id).select((d) => (d.node as RequestNode).url),
      (previous, next) {
        if (_controller.text != next) {
          _controller.text = next;
          debugPrint("URL updated from provider: $next");
        }
      },
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, left: 8, right: 8),
      child: Row(
        children: [
          // menu
          Expanded(
            child: VariableTextFieldCustom(
              controller: _controller,
              enableUrlSuggestions: true,
              id: widget.id,
              decoration: InputDecoration(
                prefixIconConstraints: BoxConstraints(maxWidth: 80),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final method = ref.watch(
                        reqComposeProvider(
                          widget.id,
                        ).select((d) => (d.node as RequestNode).method),
                      );
                      return MyCustomMenu.contentColumn(
                        popupKey: popupKey,
                        items: _buildMenuItems(method),
                        child: Text(
                          method,
                          style: TextStyle(
                            color: methodsColorsMap[method] ?? Colors.grey,
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                suffixIcon: Padding(
                  padding: const .only(right: 8),
                  child: IconButton(
                    onPressed: () {
                      sendReq();
                    },
                    icon: Icon(Icons.send),
                  ),
                ),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 12.0,
                ),
              ),
              onChanged: (v) {
                notifier.updateUrl(v);
              },
              onSubmitted: (_) {
                sendReq();
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(String checkedValue) {
    return methods.map((m) {
      return SizedBox(
        width: 150,
        child: CustomMenuIconItem.tick(
          checked: m == checkedValue,
          onTap: (val) {
            notifier.updateMethod(m);
          },
          title: Text(
            m,
            style: TextStyle(color: methodsColorsMap[m] ?? Colors.grey),
          ),
          value: m,
        ),
      );
    }).toList();
  }
}

// String resolveVariables(String text, Map<String, VariableValue> values) {
//   // Match all {{variable}} patterns
//   final regex = RegExp(r'{{\s*([a-zA-Z0-9_]+)\s*}}');

//   return text.replaceAllMapped(regex, (match) {
//     final key = match.group(1);
//     if (key != null && values.containsKey(key)) {
//       return values[key]!.value; // Replace with value
//     }
//     return match.group(0)!; // leave as is if no value found
//   });
// }

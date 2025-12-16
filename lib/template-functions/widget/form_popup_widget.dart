import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/config_resolver_provider.dart';
import 'package:api_craft/template-functions/functions/template-function-request/request_body_path.dart';
import 'package:api_craft/template-functions/functions/template-function-response/response_body_path.dart';
import 'package:api_craft/template-functions/parsers/get_default_state.dart';
import 'package:api_craft/template-functions/parsers/parse.dart';
import 'package:api_craft/template-functions/widget/form_input_widget.dart';
import 'package:api_craft/utils/debouncer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

// Center(
//       child: FilledButton(
//         onPressed: () {
//           showDialog(
//             context: context,
//             builder: (context) => const FormPopupWidget(),
//           );
//         },
//         child: Text("fn popup"),
//       ),
//     ),

void showFunctionPopup(
  BuildContext context,
  TemplateFnPlaceholder fnPlaceholder, {

  required String id,
}) {
  showDialog(
    context: context,
    builder: (context) => FormPopupWidget(fnPlaceholder: fnPlaceholder, id: id),
  );
}

class FormPopupWidget extends ConsumerStatefulWidget {
  final TemplateFnPlaceholder fnPlaceholder;
  final String id;

  const FormPopupWidget({
    super.key,
    required this.fnPlaceholder,
    required this.id,
  });

  @override
  ConsumerState<FormPopupWidget> createState() => _FormPopupWidgetState();
}

class _FormPopupWidgetState extends ConsumerState<FormPopupWidget> {
  late final fnState = getState(
    getTemplateFunctionByName(widget.fnPlaceholder.name),
    widget.fnPlaceholder.args,
  );
  String? renderedValue;
  final debouncer = Debouncer(Duration(milliseconds: 500));

  void handleSubmit() {
    debugPrint("Function confirmed with state: $fnState");
    // save state

    // update url
    final node = ref.read(reqComposeProvider(widget.id)).node;
    if (node is RequestNode) {
      final url = node.url;
      // replace node url placeholder
      final fnStr = serializePlaceholder(
        widget.fnPlaceholder.copyWithArgs(fnState),
      );
      final fnStrWithPlaceholders = "{{$fnStr}}";
      debugPrint("Serialized function string: $fnStrWithPlaceholders");
      // replace from,to index in fnPlaceholder
      final newUrl = url.replaceRange(
        widget.fnPlaceholder.start,
        widget.fnPlaceholder.end,
        fnStrWithPlaceholders,
      );
      ref.read(reqComposeProvider(widget.id).notifier).updateUrl(newUrl);
      debugPrint("Updated URL: $newUrl");
      Navigator.of(context).pop();
    }
  }

  void renderPreview() async {
    responseBody
        .onRender(
          ref,
          CallTemplateFunctionArgs(values: fnState, purpose: Purpose.preview),
        )
        .then((value) {
          debugPrint("Rendered value: $value");
          setState(() {
            renderedValue = value;
          });
        })
        .catchError((error) {
          debugPrint("Error rendering value: $error");
          setState(() {
            renderedValue = "";
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Function: ${widget.fnPlaceholder.name}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FormInputWidget(
                inputs: responseBody.args,
                data: fnState,
                onChanged: (key, value) {
                  debugPrint("Input changed: $key -> $value");
                  setState(() {
                    fnState[key] = value;
                  });
                  debouncer.run(() {
                    renderPreview();
                  });
                },
              ),
            ),
            Row(
              children: [
                Expanded(child: Text(renderedValue ?? "")),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: renderPreview,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: handleSubmit,
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
  }
}

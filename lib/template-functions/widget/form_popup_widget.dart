import 'package:api_craft/models/models.dart';
import 'package:api_craft/template-functions/parsers/utils.dart';
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
  required void Function(String Function(String val) fn) updateField,
}) {
  showDialog(
    context: context,
    builder: (context) => FormPopupWidget(
      fnPlaceholder: fnPlaceholder,
      id: id,
      updateField: updateField,
    ),
  );
}

class FormPopupWidget extends ConsumerStatefulWidget {
  final TemplateFnPlaceholder fnPlaceholder;
  final void Function(String Function(String val) fn) updateField;
  final String id;

  const FormPopupWidget({
    super.key,
    required this.fnPlaceholder,
    required this.id,
    required this.updateField,
  });

  @override
  ConsumerState<FormPopupWidget> createState() => _FormPopupWidgetState();
}

class _FormPopupWidgetState extends ConsumerState<FormPopupWidget> {
  late final templateFn = getTemplateFunctionByName(widget.fnPlaceholder.name);
  late final fnState = getFnState(templateFn, widget.fnPlaceholder.args);
  String? renderedValue;
  final debouncer = Debouncer(Duration(milliseconds: 500));
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    renderPreview();
  }

  void handleSubmit() {
    debugPrint("Function confirmed with state: $fnState");
    // save state
    if (!_formKey.currentState!.validate()) {
      debugPrint("Form is not valid");
      return;
    }

    // update url
    // replace node url placeholder
    final fnStr = serializePlaceholder(
      widget.fnPlaceholder.copyWithArgs(fnState),
    );
    final fnStrWithPlaceholders = "{{$fnStr}}";
    debugPrint("Serialized function string: $fnStrWithPlaceholders");
    widget.updateField((val) {
      return val.replaceRange(
        widget.fnPlaceholder.start,
        widget.fnPlaceholder.end,
        fnStrWithPlaceholders,
      );
    });
    Navigator.of(context).pop();
  }

  void renderPreview() async {
    templateFn
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
          crossAxisAlignment: .start,
          children: [
            Container(
              padding: .symmetric(vertical: 1, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 59, 61, 62),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${widget.fnPlaceholder.name}(...)",
                style: const TextStyle(fontSize: 17, fontWeight: .w600),
              ),
            ),
            const SizedBox(height: 10),
            Text(templateFn.description),
            const SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: FormInputWidget(
                  inputs: templateFn.args,
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
            ),
            Row(
              children: [
                Expanded(child: Text(renderedValue ?? "")),
                const SizedBox(width: 20),
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

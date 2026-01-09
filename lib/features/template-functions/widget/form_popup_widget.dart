import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/providers/ref_provider.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
import 'package:api_craft/features/template-functions/parsers/utils.dart';
import 'package:api_craft/features/template-functions/parsers/parse.dart';
import 'package:api_craft/features/template-functions/widget/form_input_widget.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class FormPopupWidget extends ConsumerStatefulWidget {
  final TemplateFnPlaceholder fnPlaceholder;
  final TemplateFunction templateFn;
  final void Function(String Function(String val) fn) updateField;
  final String? id;

  const FormPopupWidget({
    super.key,
    required this.fnPlaceholder,
    required this.templateFn,
    required this.id,
    required this.updateField,
  });

  @override
  ConsumerState<FormPopupWidget> createState() => _FormPopupWidgetState();
}

class _FormPopupWidgetState extends ConsumerState<FormPopupWidget> {
  late Map<String, dynamic> fnState = getFnState(
    widget.templateFn,
    widget.fnPlaceholder.args,
  );
  String? renderedValue;
  final debouncer = Debouncer(Duration(milliseconds: 500));
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.templateFn.previewType == "auto") {
      renderPreview("auto");
    }
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
    debugPrint("fnStr: $fnStr");
    debugPrint(
      "replace(${widget.fnPlaceholder.start}, ${widget.fnPlaceholder.end}, $fnStr)",
    );
    final fnStrWithPlaceholders = "{{$fnStr}}";
    debugPrint("Serialized function string: $fnStrWithPlaceholders");
    final start = widget.fnPlaceholder.start;
    final end = widget.fnPlaceholder.end;
    widget.updateField((val) {
      debugPrint("val: $val ,len: ${val.length}");
      if (val.isEmpty) return fnStrWithPlaceholders;
      return val.substring(0, start) +
          fnStrWithPlaceholders +
          val.substring(end);
      // return val.replaceRange(start, end, fnStrWithPlaceholders);
    });
    Navigator.of(context).pop();
  }

  void renderPreview(String previewType) async {
    final r = ref.read(refProvider);

    // resolve args values for nested functions,variables.
    final reqResolver = RequestResolver(r);
    try {
      final resolvedArgs = await reqResolver.resolveForTemplatePreview(
        widget.id,
        fnState,
        context,
        previewType,
      );
      final val = await widget.templateFn.onRender(
        r,
        context,
        CallTemplateFunctionArgs(
          values: resolvedArgs,
          purpose: Purpose.preview,
        ),
      );
      setState(() {
        renderedValue = val;
      });
    } catch (e) {
      debugPrint("Error rendering value: $e");
      setState(() {
        renderedValue = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      width: 700,
      padding: const EdgeInsets.all(16.0),

      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
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
          Text(widget.templateFn.description),
          const SizedBox(height: 16),

          /// Form
          Form(
            key: _formKey,
            child: FormInputWidget(
              id: widget.id,
              inputs: widget.templateFn.args,
              data: fnState,
              onChanged: (key, value) {
                debugPrint("Input changed: $key -> $value");
                setState(() {
                  fnState = Map.from(fnState)..[key] = value;
                });
                if (widget.templateFn.previewType == "auto") {
                  debouncer.run(() {
                    renderPreview("auto");
                  });
                }
              },
            ),
          ),

          /// Preview
          const SizedBox(height: 16),
          Container(
            padding: .symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 64, 67, 67),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    renderedValue ?? "",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: () => renderPreview("click"),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          /// Save Button
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: .end,
            children: [
              FilledButton(onPressed: handleSubmit, child: const Text("Save")),
            ],
          ),
        ],
      ),
    );
  }
}

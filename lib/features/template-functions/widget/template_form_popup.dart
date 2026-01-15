import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/providers/ref_provider.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/features/dynamic-form/form_state.dart';
import 'package:api_craft/features/template-functions/functions/secure_fn.dart';
import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
import 'package:api_craft/features/template-functions/parsers/parse.dart';
import 'package:api_craft/features/dynamic-form/dynamic_form.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/features/collection/services/collection_security_service.dart'; // collectionSecurityServiceProvider

class TemplateFormPopup extends ConsumerStatefulWidget {
  final TemplateFnPlaceholder fnPlaceholder;
  final TemplateFunction templateFn;
  final void Function(String Function(String val) fn) updateField;
  final String? id;

  const TemplateFormPopup({
    super.key,
    required this.fnPlaceholder,
    required this.templateFn,
    required this.id,
    required this.updateField,
  });

  @override
  ConsumerState<TemplateFormPopup> createState() => _TemplateFormPopupState();
}

class _TemplateFormPopupState extends ConsumerState<TemplateFormPopup> {
  late Map<String, dynamic> fnState = getFnState(
    widget.templateFn.args,
    widget.fnPlaceholder.args,
  );
  String? renderedValue;
  final debouncer = Debouncer(Duration(milliseconds: 500));
  final _formKey = GlobalKey<FormState>();
  bool _hasDecrypted = false;

  @override
  void initState() {
    super.initState();
    if (widget.templateFn.previewType == "auto") {
      renderPreview("auto");
    }
    if (widget.templateFn.name == 'secure') {
      decryptValue(getRef(ref), fnState['value']).then((decrypted) {
        debugPrint("decrypted: $decrypted");
        if (mounted) {
          setState(() {
            fnState['value'] = decrypted;
            _hasDecrypted = true;
          });
        }
      });
    }
  }

  void handleSubmit() {
    debugPrint("Function confirmed with state: $fnState");
    // save state
    if (!_formKey.currentState!.validate()) {
      debugPrint("Form is not valid");
      return;
    }

    _processAndSubmit();
  }

  Future<void> _processAndSubmit() async {
    Map<String, dynamic> finalState = Map.from(fnState);

    if (widget.templateFn.name == 'secure') {
      final value = finalState['value'];
      if (value != null && value.isNotEmpty && !value.startsWith('ENC_')) {
        final securityService = ref.read(collectionSecurityServiceProvider);
        final encrypted = await securityService.encryptData(value);
        finalState['value'] = encrypted;
      }
    }

    if (!mounted) return;

    // update url
    // replace node url placeholder
    final fnStr = serializePlaceholder(
      widget.fnPlaceholder.copyWithArgs(finalState),
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
            child: DynamicForm(
              key: ValueKey(_hasDecrypted),
              id: widget.id,
              inputs: widget.templateFn.args,
              data: fnState,
              onChanged: (key, value) {
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
          if (widget.templateFn.previewType != "disabled")
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

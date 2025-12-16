import 'package:api_craft/template-functions/functions/template-function-request/request_body_path.dart';
import 'package:api_craft/template-functions/functions/template-function-response/response_body_path.dart';
import 'package:api_craft/template-functions/widget/form_input_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class FormPopupWidget extends ConsumerStatefulWidget {
  const FormPopupWidget({super.key});

  @override
  ConsumerState<FormPopupWidget> createState() => _FormPopupWidgetState();
}

class _FormPopupWidgetState extends ConsumerState<FormPopupWidget> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16.0),
        child: FormInputWidget(inputs: responseBody.args),
      ),
    );
  }
}

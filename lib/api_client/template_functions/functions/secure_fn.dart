import 'package:api_craft/api_client/workspace/services/workspace_security_service.dart';
import 'package:api_craft/shared/dynamic_form/form_input.dart';
import 'package:api_craft/api_client/template_functions/models/template_functions.dart';
// Likely here
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

final secureFn = TemplateFunction(
  name: 'secure',
  previewType: 'disabled',
  description: 'Decrypts a secure value using the workspace context',
  args: [
    FormInputText(
      name: "value",
      label: "Value",
      optional: false,
      password: true,
    ),
  ],
  onRender: (ref, context, args) async {
    final values = args.values;
    final encryptedValue = values['value'];
    return await decryptValue(ref, encryptedValue);
  },
);

Future<String?> decryptValue(Ref ref, String? encryptedValue) async {
  try {
    if (encryptedValue == null ||
        encryptedValue.isEmpty ||
        !encryptedValue.startsWith('ENC_')) {
      debugPrint("Value is null or empty or not encrypted");
      return null;
    }
    final securityService = ref.read(workspaceSecurityServiceProvider);
    return securityService.decryptData(encryptedValue);
  } catch (e) {
    debugPrint("Error decrypting value: $e");
    rethrow;
  }
}

import 'package:api_craft/core/services/security/encryption_service.dart';
import 'package:api_craft/features/collection/services/collection_security_service.dart';
import 'package:api_craft/features/dynamic-form/form_input.dart';
import 'package:api_craft/features/template-functions/models/template_functions.dart';
import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
import 'package:api_craft/features/sidebar/file_tree_provider.dart';
import 'package:api_craft/core/providers/providers.dart'; // Likely here
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

final secureFn = TemplateFunction(
  name: 'secure',
  previewType: 'disabled',
  description: 'Decrypts a secure value using the collection context',
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
    final securityService = ref.read(collectionSecurityServiceProvider);
    return securityService.decryptData(encryptedValue);
  } catch (e) {
    debugPrint("Error decrypting value: $e");
    rethrow;
  }
}

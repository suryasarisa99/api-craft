import 'package:api_craft/core/network/raw/raw_http_req.dart';
import 'package:api_craft/core/nltm.dart';
import 'package:api_craft/features/auth/models/auth_model.dart';
import 'package:api_craft/features/dynamic-form/form_input.dart';
import 'package:collection/collection.dart';

final ntlmAuth = Authenticaion(
  type: 'windows',
  label: 'NTLM Auth',
  shortLabel: 'NTLM',
  args: [
    FormInputBanner(
      // color: const Color(0xFF2196F3), // info
      inputs: [FormInputMarkdown(content: 'NTLM is still in beta')],
    ),

    FormInputText(name: 'username', label: 'Username', optional: true),
    FormInputText(
      name: 'password',
      label: 'Password',
      password: true,
      optional: true,
    ),

    FormInputAccordion(
      label: 'Advanced',
      inputs: [
        FormInputText(name: 'domain', label: 'Domain', optional: true),
        FormInputText(
          name: 'workstation',
          label: 'Workstation',
          optional: true,
        ),
      ],
    ),
  ],

  onApply: (ref, args) async {
    final values = args.values;

    final domain = values['domain'] ?? '';
    final workstation = values['workstation'] ?? '';
    // STEP 1: Create Type1 message
    final type1 = NTLM.createType1Message(
      domain: domain,
      workstation: workstation,
    );

    final response = await sendRawHttp(
      method: args.method,
      url: Uri.parse(args.url),
      requestId: "",
      headers: [
        ["Authorization", type1],
        ["Connection", "keep-alive"],
      ],
    );

    // STEP 3: Extract WWW-Authenticate header
    final wwwAuthHeader = response.headers.firstWhereOrNull(
      (h) => h[0].toLowerCase() == 'www-authenticate',
    );

    // STEP 4: Parse Type2 message
    final type2 = NTLM.parseType2Message(wwwAuthHeader?[1] ?? '');

    // STEP 5: Create Type3 message
    final type3 = NTLM.createType3Message(
      type2!,
      domain: domain,
      workstation: workstation,
      username: values['username'] ?? '',
      password: values['password'] ?? '',
    );

    // STEP 6: Return Authorization header
    return AuthResult(
      headers: [
        ["Authorization", type3],
      ],
    );
  },
);

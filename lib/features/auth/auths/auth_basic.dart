import 'dart:convert';

import 'package:api_craft/core/models/models.dart';

final basicAuth = Authenticaion(
  type: "basic",
  label: 'Basic Auth',
  shortLabel: 'Basic',
  args: [
    FormInputText(name: 'username', label: 'Username', optional: true),
    FormInputText(
      name: 'password',
      label: 'Password',
      optional: true,
      password: true,
    ),
  ],
  onApply: (ref, args) {
    final values = args.values;
    final username = values['username'];
    final password = values['password'];
    final value = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    final headers = [
      ['Authorization', value],
    ];
    return AuthResult(headers: headers);
  },
);

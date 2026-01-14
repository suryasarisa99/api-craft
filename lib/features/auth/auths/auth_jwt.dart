import 'dart:convert';
import 'package:api_craft/features/auth/models/auth_model.dart';
import 'package:api_craft/features/dynamic-form/form_input.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

const algorithms = [
  'HS256',
  'HS384',
  'HS512',
  'RS256',
  'RS384',
  'RS512',
  'PS256',
  'PS384',
  'PS512',
  'ES256',
  'ES384',
  'ES512',
  'none',
];

final defaultAlgorithm = algorithms[0];
final jwtAuth = Authenticaion(
  type: "jwt",
  label: 'JWT Bearer',
  shortLabel: 'JWT',
  args: [
    FormInputSelect(
      name: 'algorithm',
      label: 'Algorithm',
      hideLabel: true,
      defaultValue: defaultAlgorithm,
      options: algorithms
          .map(
            (v) => FormInputSelectOption(
              label: v == 'none' ? 'None' : v,
              value: v,
            ),
          )
          .toList(),
    ),
    FormInputText(
      name: 'secret',
      label: 'Secret or Private Key',
      password: true,
      optional: true,
      multiLine: true,
    ),
    FormInputCheckbox(name: 'secretBase64', label: 'Secret is base64 encoded'),
    FormInputSelect(
      name: 'location',
      label: 'Behavior',
      defaultValue: 'header',
      options: [
        FormInputSelectOption(label: 'Insert Header', value: 'header'),
        FormInputSelectOption(label: 'Append Query Parameter', value: 'query'),
      ],
    ),
    FormInputText(
      name: 'name',
      label: 'Header Name',
      defaultValue: 'Authorization',
      optional: true,
      dynamicFn: (ref, args) {
        if (args.values['location'] == 'query') {
          return {
            'label': 'Parameter Name',
            'description':
                'The name of the query parameter to add to the request',
          };
        }
        return {
          'label': 'Header Name',
          'description': 'The name of the header to add to the request',
        };
      },
    ),
    FormInputText(
      name: 'headerPrefix',
      label: 'Header Prefix',
      optional: true,
      defaultValue: 'Bearer',
      dynamicFn: (ref, args) {
        if (args.values['location'] == 'query') {
          return {'hidden': true};
        }
      },
    ),
    FormInputEditor(
      name: 'payload',
      label: 'Payload',
      language: 'json',
      defaultValue: '{\n  "foo": "bar"\n}',
      placeholder: '{ }',
    ),
  ],
  onApply: (ref, args) {
    final values = args.values;
    final algorithm = values['algorithm'];
    final secret_ = values['secret'];
    final secretBase64 = values['secretBase64'];
    final payload = values['payload'];
    final secret = secretBase64 ? base64Decode(secret_) : secret_;

    final jwt = JWT(payload);
    final token = jwt.sign(secret, algorithm: algorithm);

    if (values['location'] == 'query') {
      final paramName = values['name'] ?? 'token';
      final paramValue = values['value'] ?? '';
      return AuthResult(
        queryParameters: [
          [paramName, paramValue],
        ],
      );
    }
    final headerPrefix = values['headerPrefix'] ?? 'Bearer';
    final headerName = values['name'] ?? 'Authorization';
    final headerValue = '$headerPrefix $token'.trim();
    return AuthResult(
      headers: [
        [headerName, headerValue],
      ],
    );
  },
);

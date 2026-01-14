import 'package:api_craft/features/auth/models/auth_model.dart';
import 'package:api_craft/features/template-functions/models/form_input.dart';

final bearerAuth = Authenticaion(
  type: "bearer",
  label: 'Bearer Token',
  shortLabel: 'Bearer',
  args: [
    FormInputText(
      name: 'token',
      label: 'Token',
      optional: true,
      password: true,
    ),
    FormInputText(
      name: 'prefix',
      label: 'Prefix',
      optional: true,
      placeholder: '',
      defaultValue: 'Bearer',
      description:
          'The prefix to use for the Authorization header, which will be of the format "<PREFIX> <TOKEN>".',
    ),
  ],
  onApply: (ref, args) {
    return {
      'setHeaders': [generateAuthorizationHeader(args.values)],
    };
  },
);
Map<String, dynamic> generateAuthorizationHeader(Map<String, dynamic> values) {
  final token = values['token'];
  final prefix = values['prefix'];
  final value = '$prefix $token'.trim();
  return {'name': 'Authorization', 'value': value};
}

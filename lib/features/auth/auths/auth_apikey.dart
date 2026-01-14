import 'package:api_craft/features/auth/models/auth_model.dart';
import 'package:api_craft/features/template-functions/models/form_input.dart';

final apiKeyAuth = Authenticaion(
  type: 'apikey',
  label: 'API Key',
  shortLabel: 'API Key',
  args: [
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
      name: 'key',
      label: 'Key',
      dynamicFn: (ref, args) {
        return args.values['location'] == 'query'
            ? {
                'label': 'Parameter Name',
                'description':
                    'The name of the query parameter to add to the request',
              }
            : {
                'label': 'Header Name',
                'description': 'The name of the header to add to the request',
              };
      },
    ),
    FormInputText(
      name: 'value',
      label: 'API Key',
      optional: true,
      password: true,
    ),
  ],
  onApply: (ref, args) {
    final key = args.values['key'] ?? '';
    final value = args.values['value'] ?? '';
    final location = args.values['location'];

    if (location == 'query') {
      return {
        'setQueryParameters': [
          {'name': key, 'value': value},
        ],
      };
    }
    return {
      'setHeaders': [
        {'name': key, 'value': value},
      ],
    };
  },
);

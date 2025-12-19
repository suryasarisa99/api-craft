import 'package:api_craft/core/models/models.dart';

final returnFormatHstak = FormInputHStack(
  inputs: [
    returnFormatInput,
    FormInputText(
      name: 'join',
      label: 'Separator',
      optional: true,
      defaultValue: ', ',
      dynamicFn: (ctx, args) {
        return {'hidden': args.values['purpose'] == Purpose.preview.name};
      },
    ),
  ],
);

final returnFormatInput = FormInputSelect(
  name: 'result',
  label: 'Return Format',
  defaultValue: Return.first.name,
  options: [
    FormInputSelectOption(label: 'First result', value: Return.first.name),
    FormInputSelectOption(label: 'Last result', value: Return.last.name),
    FormInputSelectOption(label: 'All results', value: Return.all.name),
  ],
);

final behaviorArgs = FormInputHStack(
  inputs: [
    FormInputSelect(
      name: 'behavior',
      label: 'Sending Behavior',
      defaultValue: Behavior.smart.name,
      options: [
        FormInputSelectOption(
          label: 'When no response',
          value: Behavior.smart.name,
        ),
        FormInputSelectOption(label: 'Always', value: Behavior.always.name),
        FormInputSelectOption(label: 'When expired', value: Behavior.ttl.name),
      ],
    ),
    FormInputText(
      name: 'ttl',
      label: 'TTL (seconds)',
      placeholder: '0',
      defaultValue: '0',
      description:
          'Resend the request when the latest response is older than this many seconds, or if there are no responses yet. "0" means never expires',
      dynamicFn: (ctx, args) {
        return {'hidden': args.values['behavior'] != Behavior.ttl.name};
      },
    ),
  ],
);

final requestArgs = FormInputHttpRequest(name: 'request', label: 'Request');

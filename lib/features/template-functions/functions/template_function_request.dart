import 'package:api_craft/core/models/models.dart';

final requestBodyPath = TemplateFunction(
  name: "request.body.path",
  description: "description",
  args: [
    FormInputHStack(
      inputs: [
        // option to select which result to return
        FormInputSelect(
          name: 'result',
          label: 'Return Format',
          defaultValue: Return.first.name,
          options: [
            FormInputSelectOption(
              label: 'First result',
              value: Return.first.name,
            ),
            FormInputSelectOption(
              label: 'Last result',
              value: Return.last.name,
            ),
            FormInputSelectOption(label: 'All results', value: Return.all.name),
          ],
        ),
      ],
    ),
  ],
  onRender: (ctx, args) async {
    // implement function logic here
  },
);

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:collection/collection.dart';

final cookieValueFn = TemplateFunction(
  name: 'cookie.value',
  description: 'Read the value of cookie in the jar, by name',
  args: [FormInputText(name: 'name', label: 'Cookie Name')],
  onRender: (ref, ctx, args) async {
    final name = args.values['name'];
    final cookies = ref.read(environmentProvider).selectedCookieJar?.cookies;
    final matchedcookie = cookies?.firstWhereOrNull(
      (cookie) => cookie.key == name,
    );
    return matchedcookie?.value;
  },
);

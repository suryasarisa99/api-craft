import 'package:api_craft/providers/config_resolver_provider.dart';
import 'package:api_craft/widgets/ui/filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final filterServiceProvider = Provider.autoDispose
    .family<FilterService, String>((ref, id) {
      final List<String> variables = ref.watch(
        resolveConfigProvider(id).select((d) => d.allVariables!.keys.toList()),
      );

      return FilterService(variables: variables);
    });

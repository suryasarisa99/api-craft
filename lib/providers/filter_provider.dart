import 'package:api_craft/models/node_model.dart';
import 'package:api_craft/providers/config_resolver_provider.dart';
import 'package:api_craft/providers/file_tree_provider.dart';
import 'package:api_craft/widgets/ui/filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final filterServiceProvider = Provider.autoDispose.family<FilterService, String>((
  ref,
  id,
) {
  // watch variables
  final List<String> variables = ref.watch(
    resolveConfigProvider(id).select((d) => d.allVariables!.keys.toList()),
  );

  // urls, uses read, instead of watch (because single editor,no way to change urls of other requests)
  final urlsList = ref
      .read(fileTreeProvider)
      .nodeMap
      .values
      .where((e) => e is RequestNode && e.id != id)
      .map((e) => (e as RequestNode).url)
      .toSet()
      .toList();
  final List<String> urls = Set<String>.from(urlsList).toList();

  return FilterService(variables: variables, urls: urls);
});

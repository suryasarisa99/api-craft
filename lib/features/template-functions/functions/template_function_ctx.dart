import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';

final ctxWorkspaceIdFn = TemplateFunction(
  name: 'ctx.workspace.id',
  description: 'Get the workspace Id',
  args: [],
  onRender: (ref, ctx, args) async {
    return ref.read(selectedCollectionProvider)?.id;
  },
);
final ctxWorkspaceNameFn = TemplateFunction(
  name: 'ctx.workspace.name',
  description: 'Get the workspace name',
  args: [],
  onRender: (ref, ctx, args) async {
    return ref.read(selectedCollectionProvider)?.name;
  },
);

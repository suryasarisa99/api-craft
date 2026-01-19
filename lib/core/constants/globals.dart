import 'package:api_craft/features/workspace/workspace_model.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences prefs;

const kDefaultWorkspace = WorkspaceModel(
  id: 'default_workspace',
  name: 'API Craft',
  type: WorkspaceType.database,
);

const kDefaultEnvironment = Environment(
  id: 'default_env',
  workspaceId: 'default_workspace',
  name: 'Default',
);

const kDefaultCookieJar = CookieJarModel(
  id: 'default_jar',
  workspaceId: 'default_workspace',
  name: 'Default',
);

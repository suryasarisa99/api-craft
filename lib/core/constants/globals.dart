import 'package:api_craft/features/collection/collection_model.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences prefs;

const kDefaultCollection = CollectionModel(
  id: 'default_collection',
  name: 'API Craft',
  type: CollectionType.database,
);

const kDefaultEnvironment = Environment(
  id: 'default_env',
  collectionId: 'default_collection',
  name: 'Default',
);

const kDefaultCookieJar = CookieJarModel(
  id: 'default_jar',
  collectionId: 'default_collection',
  name: 'Default',
);

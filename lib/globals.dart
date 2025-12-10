import 'package:api_craft/models/collection_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences prefs;

const kDefaultCollection = CollectionModel(
  id: 'default_collection',
  name: 'API Craft',
  type: CollectionType.database,
);

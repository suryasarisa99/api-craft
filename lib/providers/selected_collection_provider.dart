import 'dart:convert';

import 'package:api_craft/globals.dart';
import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedCollectionProvider =
    NotifierProvider<SelectedCollectionNotifier, CollectionModel?>(
      SelectedCollectionNotifier.new,
    );

class SelectedCollectionNotifier extends Notifier<CollectionModel?> {
  static const _prefKey = 'selected_collection';

  @override
  CollectionModel? build() {
    final collection = prefs.getString(_prefKey);
    if (collection == null) return null;
    final decoded = CollectionModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(collection)),
    );
    return decoded;
  }

  Future<void> select(CollectionModel collection) async {
    await prefs.setString(_prefKey, jsonEncode(collection.toMap()));
    state = collection;
  }
}

/*
- get collections (async)
- get saved collection from prefs
- 
*/
/*
- get saved collection from prefs
  - it is empty return null
- check first time app launched
  - if yes, db automatically creates default collection.
  */

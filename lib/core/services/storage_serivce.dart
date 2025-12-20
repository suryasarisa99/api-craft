import 'dart:convert';

import 'package:api_craft/core/constants/globals.dart';

class StorageSerivce {
  void setValue(String key, dynamic value) {
    prefs.setString(key, jsonEncode(value));
  }

  dynamic getValue(String key) {
    final value = prefs.getString(key);
    if (value == null) return null;
    return jsonDecode(value);
  }

  void deleteValue(String key) {
    prefs.remove(key);
  }
}

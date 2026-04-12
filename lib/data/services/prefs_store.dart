import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PrefsStore {
  final SharedPreferences prefs;

  const PrefsStore({required this.prefs});

  Future<List<T>> loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final jsonString = prefs.getString(key);
    if (jsonString == null) return <T>[];
    final List<dynamic> decoded = json.decode(jsonString) as List<dynamic>;
    return decoded.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  Future<void> saveList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final jsonString = json.encode(items.map(toJson).toList());
    await prefs.setString(key, jsonString);
  }

  Future<void> upsert<T>(
    String key,
    T item,
    bool Function(T) matcher,
    Map<String, dynamic> Function(T) toJson,
    T Function(Map<String, dynamic>) fromJson, {
    bool prepend = false,
  }) async {
    final items = await loadList<T>(key, fromJson);
    final index = items.indexWhere(matcher);
    if (index >= 0) {
      items[index] = item;
    } else {
      if (prepend) {
        items.insert(0, item);
      } else {
        items.add(item);
      }
    }
    await saveList<T>(key, items, toJson);
  }

  Future<void> removeWhere<T>(
    String key,
    bool Function(T) predicate,
    Map<String, dynamic> Function(T) toJson,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final items = await loadList<T>(key, fromJson);
    final filtered = items.where((item) => !predicate(item)).toList();
    if (filtered.length == items.length) return;
    await saveList<T>(key, filtered, toJson);
  }
}

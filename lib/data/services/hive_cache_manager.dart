import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class HiveCacheManager {
  static const String _apiCacheBoxName = 'kemono_coomer_api_cache';
  
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      await Hive.openBox(_apiCacheBoxName);
    } catch (e) {
      debugPrint('Failed to initialize Hive Cache: $e');
    }
  }
  
  static Box get _apiCacheBox => Hive.box(_apiCacheBoxName);
  
  static dynamic get(String key) {
    if(!Hive.isBoxOpen(_apiCacheBoxName)) return null;
    
    final cacheItem = _apiCacheBox.get(key);
    if(cacheItem is Map && cacheItem.containsKey('timestamp')) {
       final time = DateTime.tryParse(cacheItem['timestamp'] as String? ?? '');
       if(time != null && DateTime.now().difference(time).inDays > 7) {
         _apiCacheBox.delete(key);
         return null;
       }
       return cacheItem['data'];
    }
    
    return cacheItem;
  }
  
  static Future<void> set(String key, dynamic data) async {
    if(!Hive.isBoxOpen(_apiCacheBoxName)) return;
    try {
      await _apiCacheBox.put(key, {
        'timestamp': DateTime.now().toIso8601String(),
        'data': data
      });
      
      if (_apiCacheBox.length > 500) {
        final keysToDrop = _apiCacheBox.keys.take(_apiCacheBox.length - 500).toList();
        await _apiCacheBox.deleteAll(keysToDrop);
      }
    } catch(e) {
      debugPrint('Failed to save to Hive Cache: $e');
    }
  }
  
  static Future<void> clearCache() async {
    if(Hive.isBoxOpen(_apiCacheBoxName)) {
      await _apiCacheBox.clear();
    }
  }
}

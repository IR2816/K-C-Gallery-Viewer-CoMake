import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../../domain/entities/api_source.dart';

/// Prinsip 2: Client bertanggung jawab atas UX - Cache Management
///
/// API hanya memberikan data mentah, client yang mengatur:
/// - Cache hasil
/// - Refresh manual
/// - Storage management
class CacheManager {
  static const String _creatorCacheKey = 'cached_creators';
  static const String _postsCacheKey = 'cached_posts';
  static const String _searchHistoryKey = 'search_history';
  static const String _favoriteCreatorsKey = 'favorite_creators';
  static const String _settingsKey = 'app_settings';
  static const String _cacheVersionKey = 'cache_version';

  static const int _maxCacheAge =
      24 * 60 * 60 * 1000; // 24 hours in milliseconds
  static const int _maxCreatorsInCache = 1000;
  static const int _maxPostsPerCreator = 200;
  static const int _maxSearchHistory = 50;

  static SharedPreferences? _prefs;
  static const int _currentCacheVersion = 1;

  /// Initialize cache manager
  static Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      // Check cache version and clear if needed
      final cachedVersion = _prefs!.getInt(_cacheVersionKey) ?? 0;
      if (cachedVersion != _currentCacheVersion) {
        debugPrint('CacheManager: Cache version mismatch, clearing cache');
        await clearAllCache();
        await _prefs!.setInt(_cacheVersionKey, _currentCacheVersion);
      }

      debugPrint('CacheManager: Initialized successfully');
    } catch (e) {
      debugPrint('CacheManager: Initialization failed - $e');
    }
  }

  /// Cache creator dengan TTL
  static Future<void> cacheCreator(
    CreatorModel creator, {
    ApiSource? apiSource,
  }) async {
    try {
      await _ensureInitialized();

      final cacheData = await _getCreatorCache();
      final cacheKey = _getCreatorCacheKey(creator, apiSource);

      final cacheEntry = {
        'creator': creator.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'apiSource': apiSource?.name ?? ApiSource.kemono.name,
      };

      cacheData[cacheKey] = cacheEntry;

      // Prinsip 2: Cache management - limit cache size
      if (cacheData.length > _maxCreatorsInCache) {
        await _cleanupOldCreatorCache(cacheData);
      }

      await _prefs!.setString(_creatorCacheKey, json.encode(cacheData));
      debugPrint('CacheManager: Cached creator ${creator.name} ($cacheKey)');
    } catch (e) {
      debugPrint('CacheManager: Failed to cache creator - $e');
    }
  }

  /// Get cached creator jika masih valid
  static Future<CreatorModel?> getCachedCreator(
    String service,
    String userId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    try {
      await _ensureInitialized();

      final cacheData = await _getCreatorCache();
      final cacheKey = '$apiSource:$service:$userId';
      final cacheEntry = cacheData[cacheKey];

      if (cacheEntry == null) return null;

      final timestamp = cacheEntry['timestamp'] as int?;
      if (timestamp == null) return null;

      // Check TTL
      if (DateTime.now().millisecondsSinceEpoch - timestamp > _maxCacheAge) {
        cacheData.remove(cacheKey);
        await _prefs!.setString(_creatorCacheKey, json.encode(cacheData));
        debugPrint('CacheManager: Creator cache expired - $cacheKey');
        return null;
      }

      final creatorJson = cacheEntry['creator'] as Map<String, dynamic>?;
      if (creatorJson == null) return null;

      debugPrint('CacheManager: Creator cache hit - $cacheKey');
      return CreatorModel.fromJson(creatorJson);
    } catch (e) {
      debugPrint('CacheManager: Failed to get cached creator - $e');
      return null;
    }
  }

  /// Cache posts untuk creator
  static Future<void> cacheCreatorPosts(
    String service,
    String userId,
    List<PostModel> posts, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    try {
      await _ensureInitialized();

      final cacheData = await _getPostsCache();
      final cacheKey = '$apiSource:$service:$userId';

      final cacheEntry = {
        'posts': posts.map((p) => p.toJson()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'apiSource': apiSource.name,
      };

      // Prinsip 2: Limit posts per creator
      final limitedPosts = posts.take(_maxPostsPerCreator).toList();
      cacheEntry['posts'] = limitedPosts.map((p) => p.toJson()).toList();

      cacheData[cacheKey] = cacheEntry;
      await _prefs!.setString(_postsCacheKey, json.encode(cacheData));

      debugPrint(
        'CacheManager: Cached ${limitedPosts.length} posts for $cacheKey',
      );
    } catch (e) {
      debugPrint('CacheManager: Failed to cache posts - $e');
    }
  }

  /// Get cached posts
  static Future<List<PostModel>> getCachedCreatorPosts(
    String service,
    String userId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    try {
      await _ensureInitialized();

      final cacheData = await _getPostsCache();
      final cacheKey = '$apiSource:$service:$userId';
      final cacheEntry = cacheData[cacheKey];

      if (cacheEntry == null) return [];

      final timestamp = cacheEntry['timestamp'] as int?;
      if (timestamp == null) return [];

      // Check TTL (posts cache lebih singkat)
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          (_maxCacheAge ~/ 2)) {
        cacheData.remove(cacheKey);
        await _prefs!.setString(_postsCacheKey, json.encode(cacheData));
        debugPrint('CacheManager: Posts cache expired - $cacheKey');
        return [];
      }

      final postsJson = cacheEntry['posts'] as List<dynamic>?;
      if (postsJson == null) return [];

      debugPrint(
        'CacheManager: Posts cache hit - $cacheKey (${postsJson.length} posts)',
      );
      return postsJson
          .whereType<Map<String, dynamic>>()
          .map((json) => PostModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CacheManager: Failed to get cached posts - $e');
      return [];
    }
  }

  /// Add search history
  static Future<void> addSearchHistory(
    String query, {
    ApiSource? apiSource,
  }) async {
    try {
      await _ensureInitialized();

      final history = await getSearchHistory();
      final timestampedQuery = {
        'query': query.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'apiSource': apiSource?.name ?? ApiSource.kemono.name,
      };

      // Remove existing query
      history.removeWhere((item) => item['query'] == query.trim());

      // Add to front
      history.insert(0, timestampedQuery);

      // Limit history size
      if (history.length > _maxSearchHistory) {
        history.removeRange(_maxSearchHistory, history.length);
      }

      await _prefs!.setString(_searchHistoryKey, json.encode(history));
      debugPrint('CacheManager: Added to search history - $query');
    } catch (e) {
      debugPrint('CacheManager: Failed to add search history - $e');
    }
  }

  /// Get search history
  static Future<List<Map<String, dynamic>>> getSearchHistory() async {
    try {
      await _ensureInitialized();

      final historyJson = _prefs!.getString(_searchHistoryKey);
      if (historyJson == null) return [];

      final List<dynamic> decoded = json.decode(historyJson);
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('CacheManager: Failed to get search history - $e');
      return [];
    }
  }

  /// Clear search history
  static Future<void> clearSearchHistory() async {
    try {
      await _ensureInitialized();
      await _prefs!.remove(_searchHistoryKey);
      debugPrint('CacheManager: Cleared search history');
    } catch (e) {
      debugPrint('CacheManager: Failed to clear search history - $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      await _ensureInitialized();

      final creatorCache = await _getCreatorCache();
      final postsCache = await _getPostsCache();
      final searchHistory = await getSearchHistory();

      int validCreators = 0;
      int validPosts = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final entry in creatorCache.values) {
        final timestamp = entry['timestamp'] as int?;
        if (timestamp != null && (now - timestamp) < _maxCacheAge) {
          validCreators++;
        }
      }

      for (final entry in postsCache.values) {
        final timestamp = entry['timestamp'] as int?;
        if (timestamp != null && (now - timestamp) < (_maxCacheAge ~/ 2)) {
          final posts = entry['posts'] as List<dynamic>?;
          if (posts != null) validPosts += posts.length;
        }
      }

      return {
        'totalCreators': creatorCache.length,
        'validCreators': validCreators,
        'totalPostCaches': postsCache.length,
        'validPosts': validPosts,
        'searchHistorySize': searchHistory.length,
        'estimatedSizeMB': _estimateCacheSize(creatorCache, postsCache),
      };
    } catch (e) {
      debugPrint('CacheManager: Failed to get cache stats - $e');
      return {};
    }
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    try {
      await _ensureInitialized();

      await _prefs!.remove(_creatorCacheKey);
      await _prefs!.remove(_postsCacheKey);
      await _prefs!.remove(_searchHistoryKey);

      debugPrint('CacheManager: Cleared all cache');
    } catch (e) {
      debugPrint('CacheManager: Failed to clear cache - $e');
    }
  }

  /// Clear cache untuk creator tertentu
  static Future<void> clearCreatorCache(
    String service,
    String userId, {
    ApiSource? apiSource,
  }) async {
    try {
      await _ensureInitialized();

      final source = apiSource ?? ApiSource.kemono;
      final creatorCache = await _getCreatorCache();
      final postsCache = await _getPostsCache();

      final cacheKey = '$source:$service:$userId';

      creatorCache.remove(cacheKey);
      postsCache.remove(cacheKey);

      await _prefs!.setString(_creatorCacheKey, json.encode(creatorCache));
      await _prefs!.setString(_postsCacheKey, json.encode(postsCache));

      debugPrint('CacheManager: Cleared cache for $cacheKey');
    } catch (e) {
      debugPrint('CacheManager: Failed to clear creator cache - $e');
    }
  }

  // Helper methods

  static Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  static Future<Map<String, dynamic>> _getCreatorCache() async {
    final cacheJson = _prefs!.getString(_creatorCacheKey);
    if (cacheJson == null) return {};

    try {
      final decoded = json.decode(cacheJson);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      debugPrint('CacheManager: Failed to parse creator cache - $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getPostsCache() async {
    final cacheJson = _prefs!.getString(_postsCacheKey);
    if (cacheJson == null) return {};

    try {
      final decoded = json.decode(cacheJson);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      debugPrint('CacheManager: Failed to parse posts cache - $e');
      return {};
    }
  }

  static String _getCreatorCacheKey(
    CreatorModel creator,
    ApiSource? apiSource,
  ) {
    return '${apiSource?.name ?? ApiSource.kemono.name}:${creator.service}:${creator.id}';
  }

  static Future<void> _cleanupOldCreatorCache(
    Map<String, dynamic> cacheData,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = cacheData.entries.toList();

    // Sort by timestamp (oldest first)
    entries.sort((a, b) {
      final aTime = a.value['timestamp'] as int? ?? 0;
      final bTime = b.value['timestamp'] as int? ?? 0;
      return aTime.compareTo(bTime);
    });

    // Remove oldest entries
    final toRemove =
        entries.length - _maxCreatorsInCache + 100; // Remove extra buffer
    for (int i = 0; i < toRemove && i < entries.length; i++) {
      cacheData.remove(entries[i].key);
    }

    debugPrint('CacheManager: Cleaned up $toRemove old creator cache entries');
  }

  static double _estimateCacheSize(
    Map<String, dynamic> creatorCache,
    Map<String, dynamic> postsCache,
  ) {
    // Rough estimation in MB
    final creatorSize = creatorCache.length * 0.5; // ~500 bytes per creator
    final postsSize = postsCache.values.fold(0.0, (sum, entry) {
      final posts = entry['posts'] as List<dynamic>?;
      return sum + (posts?.length ?? 0) * 2.0; // ~2KB per post
    });

    return (creatorSize + postsSize) / 1024 / 1024;
  }
}

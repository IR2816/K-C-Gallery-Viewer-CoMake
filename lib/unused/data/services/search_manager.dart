import 'package:flutter/foundation.dart' show debugPrint;
import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../../domain/entities/api_source.dart';
import 'kemono_api.dart';

/// Prinsip 1: ID-centric Search Manager
///
/// API dioptimalkan untuk service + user_id, BUKAN search engine.
/// Prioritas:
/// 1. Search by ID (primary, real-time)
/// 2. Search by name (secondary, best-effort, cached)
class SearchManager {
  static const Map<String, CreatorModel> _creatorCache = {};
  static const Map<String, List<PostModel>> _postsCache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);
  static final Map<String, DateTime> _cacheTimestamps = {};

  /// Prinsip 1: Search by ID (primary method - real-time API)
  static Future<CreatorModel?> searchCreatorById(
    String service,
    String userId, {
    ApiSource apiSource = ApiSource.kemono,
    bool useCache = true,
  }) async {
    final cacheKey = '${apiSource.name}:$service:$userId';

    // Check cache first
    if (useCache && _isCacheValid(cacheKey)) {
      final cached = _creatorCache[cacheKey];
      if (cached != null) {
        debugPrint('SearchManager: ID search cache hit - $cacheKey');
        return cached;
      }
    }

    debugPrint('SearchManager: ID search (primary) - $service:$userId');

    try {
      final creator = await KemonoApi.getCreatorById(
        service,
        userId,
        apiSource: apiSource,
      );

      _creatorCache[cacheKey] = creator;
      _cacheTimestamps[cacheKey] = DateTime.now();
      debugPrint('SearchManager: ID search success - $cacheKey');

      return creator;
    } catch (e) {
      debugPrint('SearchManager: ID search failed - $e');
      return null;
    }
  }

  /// Prinsip 1: Search by ID dengan multiple services
  static Future<Map<String, CreatorModel?>> searchCreatorByIdAcrossServices(
    String userId, {
    List<String>? services,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final targetServices =
        services ?? ['fanbox', 'patreon', 'fantia', 'afdian', 'boosty'];
    final results = <String, CreatorModel?>{};

    debugPrint('SearchManager: Multi-service ID search - $userId');

    // Parallel search untuk performance
    final futures = targetServices.map((service) async {
      final creator = await searchCreatorById(
        service,
        userId,
        apiSource: apiSource,
      );
      return MapEntry(service, creator);
    });

    final resultsList = await Future.wait(futures);
    for (final entry in resultsList) {
      results[entry.key] = entry.value;
    }

    return results;
  }

  /// Prinsip 1: Name search (secondary method - best-effort, local/cached)
  static Future<List<CreatorModel>> searchCreatorsByName(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
    bool useCacheOnly = false,
  }) async {
    debugPrint('SearchManager: Name search (secondary) - $query');

    if (query.trim().isEmpty) {
      return [];
    }

    // Prinsip 4: Name search adalah opsional dan bisa cache-only
    if (useCacheOnly) {
      return _searchNameInCache(query, service);
    }

    try {
      // Fetch dari API (best-effort)
      final creators = await KemonoApi.searchCreatorsByName(
        query,
        apiSource: apiSource,
        service: service,
      );

      // Update cache
      for (final creator in creators) {
        final cacheKey = '${apiSource.name}:${creator.service}:${creator.id}';
        _creatorCache[cacheKey] = creator;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      return creators;
    } catch (e) {
      debugPrint(
        'SearchManager: Name search API failed, fallback to cache - $e',
      );
      // Fallback ke cache jika API gagal
      return _searchNameInCache(query, service);
    }
  }

  /// Prinsip 4: Local name search (cache only)
  static List<CreatorModel> _searchNameInCache(String query, String? service) {
    final lowerQuery = query.toLowerCase();
    final results = <CreatorModel>[];

    debugPrint('SearchManager: Local name search - $query');

    for (final creator in _creatorCache.values) {
      if (service != null && service.isNotEmpty && service != 'all') {
        if (creator.service != service) continue;
      }

      if (creator.name.toLowerCase().contains(lowerQuery) ||
          creator.id.toLowerCase().contains(lowerQuery)) {
        results.add(creator);
      }
    }

    return results;
  }

  /// Smart search: coba ID dulu, fallback ke name
  static Future<List<CreatorModel>> smartSearch(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
  }) async {
    debugPrint('SearchManager: Smart search - $query');

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    // Cek apakah ini ID (numeric)
    final isNumericId = RegExp(r'^\d+$').hasMatch(trimmedQuery);

    if (isNumericId &&
        service != null &&
        service.isNotEmpty &&
        service != 'all') {
      // Prinsip 1: Prioritas ID search
      final creator = await searchCreatorById(
        service,
        trimmedQuery,
        apiSource: apiSource,
      );
      if (creator != null) {
        return [creator];
      }

      // Jika ID tidak ditemukan, fallback ke name search
      debugPrint('SearchManager: ID not found, fallback to name search');
    }

    // Name search (secondary)
    return await searchCreatorsByName(
      trimmedQuery,
      apiSource: apiSource,
      service: service,
    );
  }

  /// Get cached creator posts
  static Future<List<PostModel>> getCachedCreatorPosts(
    String service,
    String userId,
    ApiSource apiSource,
  ) async {
    final cacheKey = '${apiSource.name}:$service:$userId:posts';

    if (_isCacheValid(cacheKey)) {
      final cached = _postsCache[cacheKey];
      if (cached != null) {
        debugPrint('SearchManager: Posts cache hit - $cacheKey');
        return cached;
      }
    }

    return [];
  }

  /// Cache creator posts
  static void cacheCreatorPosts(
    String service,
    String userId,
    ApiSource apiSource,
    List<PostModel> posts,
  ) {
    final cacheKey = '${apiSource.name}:$service:$userId:posts';
    _postsCache[cacheKey] = posts;
    _cacheTimestamps[cacheKey] = DateTime.now();
    debugPrint('SearchManager: Cached ${posts.length} posts - $cacheKey');
  }

  /// Clear cache untuk creator tertentu
  static void clearCreatorCache(
    String service,
    String userId,
    ApiSource apiSource,
  ) {
    final creatorKey = '${apiSource.name}:$service:$userId';
    final postsKey = '${apiSource.name}:$service:$userId:posts';

    _creatorCache.remove(creatorKey);
    _postsCache.remove(postsKey);
    _cacheTimestamps.remove(creatorKey);
    _cacheTimestamps.remove(postsKey);

    debugPrint('SearchManager: Cleared cache for $creatorKey');
  }

  /// Clear all cache
  static void clearAllCache() {
    _creatorCache.clear();
    _postsCache.clear();
    _cacheTimestamps.clear();
    debugPrint('SearchManager: Cleared all cache');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final validCache = _cacheTimestamps.entries
        .where((entry) => DateTime.now().difference(entry.value) < _cacheExpiry)
        .length;

    return {
      'totalCreators': _creatorCache.length,
      'totalPostCaches': _postsCache.length,
      'validCacheEntries': validCache,
      'cacheSizeMB': _calculateCacheSize(),
    };
  }

  /// Check if cache is still valid
  static bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Calculate approximate cache size
  static double _calculateCacheSize() {
    // Rough estimation
    return (_creatorCache.length * 0.5 + _postsCache.length * 2.0) /
        1024 /
        1024;
  }
}

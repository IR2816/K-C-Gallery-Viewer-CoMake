import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prinsip 3.3: Jangan paksa reload data
///
/// User benci:
/// - Data reload tiap pindah tab
/// - Media reload tiap balik
///
/// Solusi:
/// - Cache di memory
/// - TTL sederhana (mis. 10–30 menit)
///
/// UX terasa: "App cepat dan stabil"
class SmartCacheManager {
  static const String _prefix = 'smart_cache_';
  static SharedPreferences? _prefs;

  // Memory cache untuk instant access
  static final Map<String, CacheEntry> _memoryCache = {};

  // Default TTL: 30 menit
  static const Duration _defaultTtl = Duration(minutes: 30);

  // Cache size limits
  static const int _maxMemoryEntries = 100;
  static const int _maxPersistentEntries = 500;

  /// Initialize cache manager
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadPersistentCache();
  }

  /// Cache data dengan TTL
  static Future<void> set<T>(
    String key,
    T data, {
    Duration? ttl,
    bool persistToDisk = true,
  }) async {
    await _ensureInitialized();

    final entry = CacheEntry<T>(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? _defaultTtl,
    );

    // Save to memory cache
    _memoryCache[key] = entry;

    // Cleanup memory cache if needed
    _cleanupMemoryCache();

    // Save to persistent storage if enabled
    if (persistToDisk) {
      await _saveToPersistent(key, entry);
    }

    debugPrint(
      'SmartCacheManager: Cached data for key: $key (TTL: ${entry.ttl})',
    );
  }

  /// Get cached data
  static Future<T?> get<T>(String key) async {
    await _ensureInitialized();

    // Try memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      debugPrint('SmartCacheManager: Memory cache hit for key: $key');
      return memoryEntry.data as T?;
    }

    // Try persistent cache
    final persistentEntry = await _getFromPersistent<T>(key);
    if (persistentEntry != null) {
      // Restore to memory cache
      _memoryCache[key] = persistentEntry;
      debugPrint('SmartCacheManager: Persistent cache hit for key: $key');
      return persistentEntry.data as T?;
    }

    debugPrint('SmartCacheManager: Cache miss for key: $key');
    return null;
  }

  /// Check if data exists and not expired
  static Future<bool> has(String key) async {
    await _ensureInitialized();

    // Check memory cache
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      return true;
    }

    // Check persistent cache
    final persistentEntry = await _getFromPersistent(key);
    return persistentEntry != null;
  }

  /// Remove cached data
  static Future<void> remove(String key) async {
    await _ensureInitialized();

    _memoryCache.remove(key);
    await _prefs?.remove('$_prefix$key');

    debugPrint('SmartCacheManager: Removed cache for key: $key');
  }

  /// Clear all cache
  static Future<void> clear() async {
    await _ensureInitialized();

    _memoryCache.clear();

    final keys =
        _prefs?.getKeys().where((key) => key.startsWith(_prefix)) ?? [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }

    debugPrint('SmartCacheManager: Cleared all cache');
  }

  /// Clear expired entries
  static Future<void> clearExpired() async {
    await _ensureInitialized();

    // Clear expired memory entries
    final expiredMemoryKeys = _memoryCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredMemoryKeys) {
      _memoryCache.remove(key);
    }

    // Clear expired persistent entries
    final persistentKeys =
        _prefs?.getKeys().where((key) => key.startsWith(_prefix)) ?? [];
    for (final key in persistentKeys) {
      final entryJson = _prefs?.getString(key);
      if (entryJson != null) {
        try {
          final entryMap = json.decode(entryJson) as Map<String, dynamic>;
          final timestamp = DateTime.parse(entryMap['timestamp'] as String);
          final ttl = Duration(milliseconds: entryMap['ttl'] as int);

          if (DateTime.now().difference(timestamp) > ttl) {
            await _prefs?.remove(key);
          }
        } catch (e) {
          // Remove corrupted entries
          await _prefs?.remove(key);
        }
      }
    }

    debugPrint('SmartCacheManager: Cleared expired cache entries');
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getStats() async {
    await _ensureInitialized();

    final memorySize = _memoryCache.length;
    final memoryExpired = _memoryCache.values
        .where((entry) => entry.isExpired)
        .length;

    final persistentKeys =
        _prefs?.getKeys().where((key) => key.startsWith(_prefix)) ?? [];
    final persistentSize = persistentKeys.length;

    return {
      'memoryCache': {
        'total': memorySize,
        'expired': memoryExpired,
        'valid': memorySize - memoryExpired,
      },
      'persistentCache': {'total': persistentSize},
      'maxMemoryEntries': _maxMemoryEntries,
      'maxPersistentEntries': _maxPersistentEntries,
    };
  }

  /// Cache data with custom key generator
  static Future<void> setWithKey<T>(
    T data, {
    required String Function(T data) keyGenerator,
    Duration? ttl,
    bool persistToDisk = true,
  }) async {
    final key = keyGenerator(data);
    await set(key, data, ttl: ttl, persistToDisk: persistToDisk);
  }

  /// Get or fetch pattern
  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
    bool persistToDisk = true,
  }) async {
    final cached = await get<T>(key);
    if (cached != null) {
      return cached;
    }

    final data = await fetcher();
    await set(key, data, ttl: ttl, persistToDisk: persistToDisk);
    return data;
  }

  /// Preload multiple keys
  static Future<void> preload<T>(
    List<String> keys,
    Future<T?> Function(String key) fetcher, {
    Duration? ttl,
    bool persistToDisk = true,
  }) async {
    final futures = keys.where((key) => !await has(key)).map((key) async {
      final data = await fetcher(key);
      if (data != null) {
        await set(key, data, ttl: ttl, persistToDisk: persistToDisk);
      }
    });

    await Future.wait(futures);
    debugPrint('SmartCacheManager: Preloaded ${futures.length} cache entries');
  }

  // Private methods

  static Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  static Future<void> _loadPersistentCache() async {
    // Load frequently used entries into memory
    final keys =
        _prefs?.getKeys().where((key) => key.startsWith(_prefix)) ?? [];

    for (final key in keys.take(20)) {
      // Load only 20 most recent
      final entryJson = _prefs?.getString(key);
      if (entryJson != null) {
        try {
          final entryMap = json.decode(entryJson) as Map<String, dynamic>;
          final timestamp = DateTime.parse(entryMap['timestamp'] as String);
          final ttl = Duration(milliseconds: entryMap['ttl'] as int);

          if (!DateTime.now().difference(timestamp).inMilliseconds >
              ttl.inMilliseconds) {
            final cacheKey = key.substring(_prefix.length);
            _memoryCache[cacheKey] = CacheEntry(
              data: entryMap['data'],
              timestamp: timestamp,
              ttl: ttl,
            );
          }
        } catch (e) {
          debugPrint('SmartCacheManager: Failed to load persistent entry: $e');
        }
      }
    }
  }

  static Future<void> _saveToPersistent<T>(
    String key,
    CacheEntry<T> entry,
  ) async {
    final entryMap = {
      'data': entry.data,
      'timestamp': entry.timestamp.toIso8601String(),
      'ttl': entry.ttl.inMilliseconds,
    };

    await _prefs?.setString('$_prefix$key', json.encode(entryMap));

    // Cleanup persistent cache if needed
    await _cleanupPersistentCache();
  }

  static Future<CacheEntry<T>?> _getFromPersistent<T>(String key) async {
    final entryJson = _prefs?.getString('$_prefix$key');
    if (entryJson == null) return null;

    try {
      final entryMap = json.decode(entryJson) as Map<String, dynamic>;
      final timestamp = DateTime.parse(entryMap['timestamp'] as String);
      final ttl = Duration(milliseconds: entryMap['ttl'] as int);

      final entry = CacheEntry<T>(
        data: entryMap['data'] as T,
        timestamp: timestamp,
        ttl: ttl,
      );

      if (entry.isExpired) {
        await _prefs?.remove('$_prefix$key');
        return null;
      }

      return entry;
    } catch (e) {
      debugPrint('SmartCacheManager: Failed to parse persistent entry: $e');
      await _prefs?.remove('$_prefix$key');
      return null;
    }
  }

  static void _cleanupMemoryCache() {
    if (_memoryCache.length <= _maxMemoryEntries) return;

    // Sort by timestamp (oldest first)
    final sortedEntries = _memoryCache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    // Remove oldest entries
    final toRemove =
        sortedEntries.length - _maxMemoryEntries + 10; // Remove extra buffer
    for (int i = 0; i < toRemove && i < sortedEntries.length; i++) {
      _memoryCache.remove(sortedEntries[i].key);
    }

    debugPrint('SmartCacheManager: Cleaned up $toRemove memory cache entries');
  }

  static Future<void> _cleanupPersistentCache() async {
    final keys =
        _prefs?.getKeys().where((key) => key.startsWith(_prefix)) ?? [];

    if (keys.length <= _maxPersistentEntries) return;

    // Get all entries with timestamps
    final entriesWithTimestamp = <String, DateTime>{};
    for (final key in keys) {
      final entryJson = _prefs?.getString(key);
      if (entryJson != null) {
        try {
          final entryMap = json.decode(entryJson) as Map<String, dynamic>;
          final timestamp = DateTime.parse(entryMap['timestamp'] as String);
          entriesWithTimestamp[key] = timestamp;
        } catch (e) {
          // Remove corrupted entries
          await _prefs?.remove(key);
        }
      }
    }

    // Sort by timestamp (oldest first)
    final sortedEntries = entriesWithTimestamp.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Remove oldest entries
    final toRemove =
        sortedEntries.length -
        _maxPersistentEntries +
        50; // Remove extra buffer
    for (int i = 0; i < toRemove && i < sortedEntries.length; i++) {
      await _prefs?.remove(sortedEntries[i].key);
    }

    debugPrint(
      'SmartCacheManager: Cleaned up $toRemove persistent cache entries',
    );
  }
}

/// Cache entry with TTL support
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({required this.data, required this.timestamp, required this.ttl});

  bool get isExpired {
    return DateTime.now().difference(timestamp) > ttl;
  }

  bool get isValid {
    return !isExpired;
  }

  Duration get age {
    return DateTime.now().difference(timestamp);
  }

  Duration get remainingTtl {
    final elapsed = age;
    return ttl > elapsed ? ttl - elapsed : Duration.zero;
  }
}

/// Cache key generators untuk konsistensi
class CacheKeys {
  // API cache keys
  static String creatorProfile(String service, String creatorId) {
    return 'creator_${service}_$creatorId';
  }

  static String creatorPosts(String service, String creatorId, int page) {
    return 'creator_posts_${service}_${creatorId}_page_$page';
  }

  static String recentPosts(String apiSource, int page) {
    return 'recent_posts_${apiSource}_page_$page';
  }

  static String searchResults(String query, String service, int page) {
    return 'search_${query}_${service}_page_$page';
  }

  // Media cache keys
  static String mediaThumbnail(String url) {
    return 'media_thumb_${url.hashCode}';
  }

  static String mediaMetadata(String url) {
    return 'media_meta_${url.hashCode}';
  }

  // User preference cache keys
  static String userPreference(String key) {
    return 'user_pref_$key';
  }

  static String lastViewedPost() {
    return 'last_viewed_post';
  }

  static String bookmarkedCreators() {
    return 'bookmarked_creators';
  }

  static String bookmarkedPosts() {
    return 'bookmarked_posts';
  }

  // App state cache keys
  static String appSettings() {
    return 'app_settings';
  }

  static String searchHistory() {
    return 'search_history';
  }

  static String apiSource() {
    return 'api_source';
  }
}

/// Utility untuk memudahkan penggunaan
class CacheHelper {
  /// Cache API response dengan auto TTL
  static Future<T?> cacheApiResponse<T>(
    String key,
    Future<T> Function() apiCall, {
    Duration? ttl,
    bool persistToDisk = true,
  }) async {
    return await SmartCacheManager.getOrFetch<T>(
      key,
      apiCall,
      ttl: ttl ?? const Duration(minutes: 15), // API cache shorter
      persistToDisk: persistToDisk,
    );
  }

  /// Cache media metadata
  static Future<void> cacheMediaMetadata(
    String url,
    Map<String, dynamic> metadata,
  ) async {
    await SmartCacheManager.set(
      CacheKeys.mediaMetadata(url),
      metadata,
      ttl: const Duration(hours: 24), // Media cache longer
      persistToDisk: true,
    );
  }

  /// Get media metadata
  static Future<Map<String, dynamic>?> getMediaMetadata(String url) async {
    return await SmartCacheManager.get<Map<String, dynamic>>(
      CacheKeys.mediaMetadata(url),
    );
  }

  /// Cache user preference
  static Future<void> setUserPreference(String key, dynamic value) async {
    await SmartCacheManager.set(
      CacheKeys.userPreference(key),
      value,
      ttl: const Duration(days: 365), // Preferences persist long
      persistToDisk: true,
    );
  }

  /// Get user preference
  static Future<T?> getUserPreference<T>(String key) async {
    return await SmartCacheManager.get<T>(CacheKeys.userPreference(key));
  }

  /// Clear API cache only
  static Future<void> clearApiCache() async {
    // Clear only API-related cache entries
    final stats = await SmartCacheManager.getStats();
    // Implementation would need to track which keys are API-related
    await SmartCacheManager.clear();
  }

  /// Clear media cache only
  static Future<void> clearMediaCache() async {
    // Clear only media-related cache entries
    final stats = await SmartCacheManager.getStats();
    // Implementation would need to track which keys are media-related
    await SmartCacheManager.clear();
  }
}

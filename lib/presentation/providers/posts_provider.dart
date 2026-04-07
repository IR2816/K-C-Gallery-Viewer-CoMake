import 'package:flutter/foundation.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import 'settings_provider.dart';
import '../../utils/logger.dart';
import '../../data/utils/api_response_utils.dart';

class PostsProvider with ChangeNotifier {
  final KemonoRepository repository;
  final SettingsProvider settingsProvider;

  PostsProvider({required this.repository, required this.settingsProvider});

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  ApiSource?
  _currentApiSource; // Track which API source was used for current posts
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Generation counter: incremented on every refresh/clear so in-flight
  // responses from a previous session are discarded when they arrive late.
  int _loadGeneration = 0;

  // Separate lists for different contexts to prevent state contamination
  List<Post> _savedPosts = [];
  bool _isLoadingSavedPosts = false;
  bool _hasMoreSavedPosts = true;
  String? _savedPostsError;
  int _savedPostsOffset = 0;

  // Separate pagination state for the latest-posts feed so that navigation to
  // creator / search screens (which overwrite _offset / _hasMore / _currentApiSource)
  // does not corrupt the latest-posts infinite scroll.
  int _latestPostsOffset = 0;
  bool _latestPostsHasMore = true;
  ApiSource? _latestPostsApiSource;

  // Dedicated post list for the latest-posts feed, kept separate from the
  // creator/search _posts list so the two screens never corrupt each other.
  List<Post> _latestPosts = [];

  List<Post> get posts => _posts;
  List<Post> get latestPosts => _latestPosts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get latestPostsHasMore => _latestPostsHasMore;
  String? get error => _error;
  ApiSource? get currentApiSource => _currentApiSource;

  /// The API source that was used to load the latest-posts feed.
  /// This is separate from [currentApiSource], which is also updated by
  /// creator/search loads and should NOT be used to determine whether the
  /// feed needs a reload.
  ApiSource? get latestPostsApiSource => _latestPostsApiSource;
  
  /// Get display name of current API source (e.g., "Kemono" or "Coomer")
  String get currentApiSourceDisplayName {
    if (_currentApiSource == null) {
      return settingsProvider.defaultApiSource.name.toUpperCase();
    }
    return _currentApiSource!.name.toUpperCase();
  }

  // Saved posts getters
  List<Post> get savedPosts => _savedPosts;
  bool get isLoadingSavedPosts => _isLoadingSavedPosts;
  bool get hasMoreSavedPosts => _hasMoreSavedPosts;
  String? get savedPostsError => _savedPostsError;

  // Get API source, preferring successful domain if available (for creator posts)
  String getEffectiveApiSource() {
    final successfulDomain = repository.getLastSuccessfulDomain();
    if (successfulDomain != null) {
      if (successfulDomain.contains('kemono.cr')) {
        return 'kemono'; // kemono.cr works for kemono
      } else if (successfulDomain.contains('coomer.st')) {
        return 'coomer'; // coomer.st works for coomer
      }
    }
    return settingsProvider.defaultApiSource.name; // fallback to default
  }

  // Get API source for latest posts (uses settings directly)
  String getLatestPostsApiSource() {
    return settingsProvider.defaultApiSource.name;
  }

  Future<void> loadCreatorPosts(
    String service,
    String creatorId, {
    bool refresh = false,
    ApiSource? apiSource,
  }) async {
    AppLogger.debug('🔍 DEBUG: PostsProvider.loadCreatorPosts called');
    AppLogger.debug(
      '🔍 DEBUG: service: $service, creatorId: $creatorId, refresh: $refresh',
    );

    if (refresh) {
      _loadGeneration++; // Invalidate any in-flight load from a previous session
      _offset = 0;
      _posts.clear(); // Clear existing posts to prevent memory leak
      _hasMore = true;
      _isLoading = false; // Allow this refresh even if a previous load was running
    }

    if (_isLoading || !_hasMore) {
      AppLogger.debug('🔍 DEBUG: Already loading or no more posts, returning');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _loadGeneration; // Capture generation for this load

    try {
      // Determine API source based on explicit selection first, then service fallback.
      final effectiveApiSource = apiSource ?? _getApiSourceForService(service);
      _currentApiSource = effectiveApiSource;
      // Keep retry counts low: the inner RetryHttpClient already retries at the
      // HTTP layer, so a high outer count multiplies the total wait time
      // dramatically (e.g. 5 outer × 4 inner × 15 s = 300 s before an error).
      final maxRetries = effectiveApiSource == ApiSource.coomer ? 2 : 1;

      await ApiResponseUtils.withRetry(
        () async {
          final newPosts = await repository.getCreatorPosts(
            service,
            creatorId,
            offset: _offset,
            apiSource: effectiveApiSource,
          );

          // Discard result if a newer refresh has started since this load began
          if (_loadGeneration != generation) {
            AppLogger.debug('🔍 DEBUG: Discarding stale load result (generation mismatch)');
            return;
          }

          if (newPosts.isEmpty) {
            _hasMore = false;
            return;
          }

          _posts.addAll(newPosts);
          _offset += newPosts.length;
        },
        maxRetries: maxRetries,
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt,
            exponentialForCoomer: true),
      );
    } catch (e) {
      if (_loadGeneration == generation) {
        _error = _getErrorMessage(e, _currentApiSource ?? ApiSource.kemono);
      }
    } finally {
      if (_loadGeneration == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // HELPER METHOD - User-friendly error messages
  String _getErrorMessage(
    dynamic error,
    ApiSource apiSource,
  ) {
    final errorString = error.toString().toLowerCase();

    if (apiSource == ApiSource.coomer) {
      if (errorString.contains('timeout') ||
          errorString.contains('connection')) {
        return 'Coomer servers are slow. Please tap Retry to try again.';
      } else if (errorString.contains('404') ||
          errorString.contains('not found')) {
        return 'Creator not found on Coomer servers';
      } else if (errorString.contains('503') ||
          errorString.contains('unavailable')) {
        return 'Coomer servers temporarily unavailable. Please tap Retry to try again.';
      } else if (errorString.contains('socket') ||
          errorString.contains('network')) {
        return 'Network issue with Coomer. Please tap Retry to try again.';
      } else {
        return 'Coomer server error. Please tap Retry to try again.';
      }
    } else {
      if (errorString.contains('timeout')) {
        return 'Connection timeout. Please tap Retry to try again.';
      } else if (errorString.contains('404')) {
        return 'Content not found';
      } else if (errorString.contains('503') ||
          errorString.contains('unavailable')) {
        return 'Server temporarily unavailable. Please tap Retry to try again.';
      } else if (errorString.contains('socket') ||
          errorString.contains('network')) {
        return 'Network connection issue. Please tap Retry to try again.';
      } else {
        return 'Loading error. Please tap Retry to try again.';
      }
    }
  }

  bool _isRetryableError(Object error, ApiSource apiSource) {
    if (apiSource == ApiSource.coomer) return true;

    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('503') ||
        errorString.contains('unavailable') ||
        errorString.contains('socket') ||
        errorString.contains('network');
  }

  Duration _retryDelay(
    ApiSource apiSource,
    int attempt, {
    bool exponentialForCoomer = true,
  }) {
    int delayMs;
    if (apiSource == ApiSource.coomer && exponentialForCoomer) {
      delayMs = 1000 * (1 << attempt);
    } else {
      delayMs = 500 * (attempt + 1);
    }
    delayMs = delayMs.clamp(0, 10000);
    return Duration(milliseconds: delayMs);
  }

  Future<void> searchPosts(String query, {bool refresh = false}) async {
    if (refresh) {
      _loadGeneration++; // Invalidate any in-flight load from a previous session
      _offset = 0;
      _posts.clear(); // Clear existing posts to prevent memory leak
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _loadGeneration; // Capture generation for this load

    try {
      final newPosts = await repository.searchPosts(
        query,
        offset: _offset,
        limit: 50,
        apiSource: settingsProvider.defaultApiSource,
      );

      // Discard result if a newer refresh has started since this load began
      if (_loadGeneration != generation) {
        AppLogger.debug('🔍 DEBUG: Discarding stale searchPosts result (generation mismatch)');
        return;
      }

      _currentApiSource = settingsProvider.defaultApiSource;

      if (newPosts.isEmpty) {
        _hasMore = false;
      } else {
        _posts.addAll(newPosts);
        _offset += newPosts.length;
      }
      _error = null;
    } catch (e) {
      if (_loadGeneration == generation) {
        _error = e.toString();
      }
    } finally {
      if (_loadGeneration == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadLatestPosts({
    bool refresh = false,
    String filter = 'latest',
    ApiSource? apiSource,
  }) async {
    if (refresh) {
      _loadGeneration++; // Invalidate any in-flight load from a previous session
      _latestPostsOffset = 0;
      _latestPosts.clear(); // Clear latest-posts list (creator _posts are unaffected)
      _latestPostsHasMore = true;
    }

    if (_isLoading || (!_latestPostsHasMore && !refresh)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _loadGeneration; // Capture generation for this load

    try {
      // IMPORTANT: Set API source at START and stick to it for entire session
      // Never auto-switch to other API - user controls API selection only
      final effectiveApiSource = apiSource ?? settingsProvider.defaultApiSource;
      _currentApiSource = effectiveApiSource;
      _latestPostsApiSource = effectiveApiSource;
      
      AppLogger.debug(
        '🔍 DEBUG: loadLatestPosts - Using API source: $effectiveApiSource (locked for this session)',
      );

      final maxRetries = effectiveApiSource == ApiSource.coomer ? 6 : 3;

      await ApiResponseUtils.withRetry(
        () async {
          AppLogger.debug(
            '🔍 DEBUG: Attempting to load latest posts from ${effectiveApiSource.name}',
          );

          // Use different query based on filter
          String query;
          switch (filter) {
            case 'random':
              query = '';
              break;
            case 'popular':
              query = 'sort:popular';
              break;
            default:
              query = ' ';
          }

          try {
            final newPosts = await repository.searchPosts(
              query,
              offset: _latestPostsOffset,
              limit: 50,
              apiSource: effectiveApiSource,
            );

            // Discard result if a newer refresh has started since this load began
            if (_loadGeneration != generation) {
              AppLogger.debug('🔍 DEBUG: Discarding stale loadLatestPosts result (generation mismatch)');
              return;
            }

            if (newPosts.isEmpty) {
              _latestPostsHasMore = false;
            } else {
              _latestPosts.addAll(newPosts);
              _latestPostsOffset += newPosts.length;
            }

            _error = null;
          } catch (e) {
            if (!_isRetryableError(e, effectiveApiSource)) {
              throw ApiResponseUtils.nonRetryable(e);
            }
            rethrow;
          }
        },
        maxRetries: maxRetries,
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt,
            exponentialForCoomer: true),
      );
    } catch (e) {
      if (_loadGeneration == generation) {
        _error = 'Failed to load latest posts. Please try again or switch API in Settings.';
        AppLogger.debug('🔍 DEBUG: Final error in loadLatestPosts: $e');
      }
    } finally {
      if (_loadGeneration == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Load the next page of latest posts, always using the API source that was
  /// locked when [loadLatestPosts] was first called (prevents domain mixing).
  Future<void> loadMoreLatestPosts() async {
    if (_isLoading || !_latestPostsHasMore) return;

    // Always use the API source that was locked at the start of this latest-posts session.
    final effectiveApiSource = _latestPostsApiSource ?? settingsProvider.defaultApiSource;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _loadGeneration;

    try {
      AppLogger.debug(
        '🔍 DEBUG: loadMoreLatestPosts - Continuing with ${effectiveApiSource.name} (offset: $_latestPostsOffset)',
      );

      final maxRetries = effectiveApiSource == ApiSource.coomer ? 6 : 3;

      await ApiResponseUtils.withRetry(
        () async {
          try {
            final newPosts = await repository.searchPosts(
              ' ',
              offset: _latestPostsOffset,
              limit: 50,
              apiSource: effectiveApiSource,
            );

            if (_loadGeneration != generation) {
              AppLogger.debug('🔍 DEBUG: Discarding stale loadMoreLatestPosts result (generation mismatch)');
              return;
            }

            if (newPosts.isEmpty) {
              _latestPostsHasMore = false;
              return;
            }

            _latestPosts.addAll(newPosts);
            _latestPostsOffset += newPosts.length;
            _error = null;
          } catch (e) {
            if (!_isRetryableError(e, effectiveApiSource)) {
              throw ApiResponseUtils.nonRetryable(e);
            }
            rethrow;
          }
        },
        maxRetries: maxRetries,
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt,
            exponentialForCoomer: true),
      );
    } catch (e) {
      if (_loadGeneration == generation) {
        _error = 'Failed to load more posts. Please try again.';
        AppLogger.debug('🔍 DEBUG: Final error in loadMoreLatestPosts: $e');
      }
    } finally {
      if (_loadGeneration == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    // Use the SAME API source that was used to load the initial posts
    // DO NOT switch to settingsProvider.defaultApiSource
    final effectiveApiSource = _currentApiSource ?? settingsProvider.defaultApiSource;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _loadGeneration; // Capture generation for this load

    try {
      AppLogger.debug(
        '🔍 DEBUG: loadMorePosts - Continuing with ${effectiveApiSource.name} (offset: $_offset)',
      );

      final maxRetries = effectiveApiSource == ApiSource.coomer ? 6 : 3;

      await ApiResponseUtils.withRetry(
        () async {
          try {
            final newPosts = await repository.searchPosts(
              ' ',
              offset: _offset,
              limit: 50,
              apiSource: effectiveApiSource,
            );

            // Discard result if a newer refresh has started since this load began
            if (_loadGeneration != generation) {
              AppLogger.debug('🔍 DEBUG: Discarding stale loadMorePosts result (generation mismatch)');
              return;
            }

            if (newPosts.isEmpty) {
              _hasMore = false;
              return;
            }

            _posts.addAll(newPosts);
            _offset += newPosts.length;

            _error = null;
          } catch (e) {
            if (!_isRetryableError(e, effectiveApiSource)) {
              throw ApiResponseUtils.nonRetryable(e);
            }
            rethrow;
          }
        },
        maxRetries: maxRetries,
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt,
            exponentialForCoomer: true),
      );
    } catch (e) {
      if (_loadGeneration == generation) {
        _error = 'Failed to load more posts. Please try again.';
        AppLogger.debug('🔍 DEBUG: Final error in loadMorePosts: $e');
      }
    } finally {
      if (_loadGeneration == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchByTags(List<String> tags, {bool refresh = false}) async {
    if (refresh) {
      _loadGeneration++; // Invalidate any in-flight load from a previous session
      _offset = 0;
      _posts.clear(); // Clear existing posts to prevent memory leak
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _loadGeneration; // Capture generation for this load

    try {
      final newPosts = await repository.getPostsByTags(
        tags,
        offset: _offset,
        apiSource: settingsProvider.defaultApiSource,
      );

      // Discard result if a newer refresh has started since this load began
      if (_loadGeneration != generation) {
        AppLogger.debug('🔍 DEBUG: Discarding stale searchByTags result (generation mismatch)');
        return;
      }

      _currentApiSource = settingsProvider.defaultApiSource;

      if (newPosts.isEmpty) {
        _hasMore = false;
      } else {
        _posts.addAll(newPosts);
        _offset += newPosts.length;
      }
      _error = null;
    } catch (e) {
      if (_loadGeneration == generation) {
        _error = e.toString();
      }
    } finally {
      if (_loadGeneration == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  int get retryCount => _retryCount;
  bool get canRetry => _retryCount < _maxRetries && _error != null;

  void reset() {
    _loadGeneration++; // Invalidate any in-flight load
    _posts.clear(); // Clear existing posts to prevent memory leak
    _latestPosts.clear();
    _isLoading = false;
    _hasMore = true;
    _latestPostsHasMore = true;
    _latestPostsOffset = 0;
    _error = null;
    _offset = 0;
    _currentApiSource = null;
    _retryCount = 0;
    notifyListeners();
  }

  void clearPosts() {
    _loadGeneration++; // Invalidate any in-flight load
    // Only clear the creator/search _posts; _latestPosts belongs to the feed.
    _posts.clear();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> retryLastOperation() async {
    if (!canRetry) return;

    _retryCount++;
    _error = null;
    notifyListeners();

    try {
      if (_posts.isNotEmpty) {
        // Retry the last successful operation type
        await loadMorePosts();
      } else {
        // Try loading latest posts as fallback
        await loadLatestPosts(refresh: true);
      }
    } catch (e) {
      _error = 'Retry failed: $e';
      notifyListeners();
    }
  }

  void resetRetry() {
    _retryCount = 0;
    _error = null;
    notifyListeners();
  }

  Future<void> toggleSavePost(Post post) async {
    try {
      // Use a single indexWhere instead of any() + indexWhere() to halve the
      // number of linear scans on the saved-posts list.
      final savedIndex = _savedPosts.indexWhere((p) => p.id == post.id);
      final isCurrentlySaved = savedIndex != -1;

      if (isCurrentlySaved) {
        // Remove from saved
        await repository.removeSavedPost(post.id);
      } else {
        // Add to saved
        await repository.savePost(post);
      }

      // Update main posts list
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(saved: !isCurrentlySaved);
      }

      // Update saved posts list
      if (isCurrentlySaved) {
        // Post was saved, now unsaved - remove from saved posts
        _savedPosts.removeAt(savedIndex);
      } else {
        // Post was unsaved, now saved - add to saved posts
        _savedPosts.insert(0, post.copyWith(saved: true)); // Add to beginning
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load single post with full content - ENHANCED WITH AUTO-RETRY
  Future<void> loadSinglePost(
    String service,
    String creatorId,
    String postId, {
    ApiSource? apiSource,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Determine API source based on service if not provided
      final effectiveApiSource = apiSource ?? _getApiSourceForService(service);
      _currentApiSource = effectiveApiSource;
      AppLogger.debug(
        '🔍 DEBUG: loadSinglePost using apiSource: $effectiveApiSource for service: $service',
      );

      final maxRetries = effectiveApiSource == ApiSource.coomer ? 6 : 3;

      await ApiResponseUtils.withRetry(
        () async {
          try {
            final post = await repository.getPost(
              service,
              creatorId,
              postId,
              apiSource: effectiveApiSource,
            );

            final existingIndex = _posts.indexWhere((p) => p.id == postId);
            if (existingIndex != -1) {
              _posts[existingIndex] = post;
            } else {
              _posts.insert(0, post);
            }

            _error = null;
            debugPrint(
              'PostsProvider: Single post loaded successfully - ${post.id}',
            );
          } catch (e) {
            if (!_isRetryableError(e, effectiveApiSource)) {
              throw ApiResponseUtils.nonRetryable(e);
            }
            rethrow;
          }
        },
        maxRetries: maxRetries,
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt,
            exponentialForCoomer: true),
      );
    } catch (e) {
      _error = _getErrorMessage(e, _currentApiSource ?? ApiSource.kemono);
      AppLogger.debug('🔍 DEBUG: Final error in loadSinglePost: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get API source based on service
  ApiSource _getApiSourceForService(String service) {
    switch (service.toLowerCase()) {
      case 'onlyfans':
      case 'fansly':
      case 'candfans':
        return ApiSource.coomer;
      case 'patreon':
      case 'fanbox':
      case 'fantia':
      default:
        return ApiSource.kemono;
    }
  }

  /// Load saved posts
  Future<void> loadSavedPosts({bool refresh = false}) async {
    if (refresh) {
      _savedPostsOffset = 0;
      _savedPosts.clear(); // Clear existing saved posts to prevent memory leak
      _hasMoreSavedPosts = true;
      _isLoadingSavedPosts = false;
      _savedPostsError = null;
    }

    _isLoadingSavedPosts = true;
    _savedPostsError = null;
    notifyListeners();

    try {
      final newPosts = await repository.getSavedPosts(
        offset: _savedPostsOffset,
      );

      if (refresh) {
        _savedPosts = newPosts;
      } else {
        _savedPosts.addAll(newPosts);
      }

      _savedPostsOffset += newPosts.length;
      _hasMoreSavedPosts = newPosts.length >= 50;
      _isLoadingSavedPosts = false;
      _savedPostsError = null;
      _retryCount = 0;
    } catch (e) {
      _savedPostsError = e.toString();
      _isLoadingSavedPosts = false;
    }

    notifyListeners();
  }

  /// Get a specific post by service, creator_id, and post_id
  Future<void> getSpecificPost(
    String service,
    String creatorId,
    String postId,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await repository.getPost(service, creatorId, postId);
      _posts = [post]; // Replace current posts with the specific post
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _posts.clear(); // Clear posts if error
    }

    notifyListeners();
  }
}

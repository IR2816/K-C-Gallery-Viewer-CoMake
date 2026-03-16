import 'package:flutter/foundation.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import 'settings_provider.dart';
import '../../utils/logger.dart';

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

  // Separate lists for different contexts to prevent state contamination
  List<Post> _savedPosts = [];
  bool _isLoadingSavedPosts = false;
  bool _hasMoreSavedPosts = true;
  String? _savedPostsError;
  int _savedPostsOffset = 0;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  ApiSource? get currentApiSource => _currentApiSource;

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
      _offset = 0;
      _posts.clear(); // Clear existing posts to prevent memory leak
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) {
      AppLogger.debug('🔍 DEBUG: Already loading or no more posts, returning');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Determine API source based on explicit selection first, then service fallback.
      final effectiveApiSource = apiSource ?? _getApiSourceForService(service);
      _currentApiSource = effectiveApiSource;

      // AUTO-RETRY MECHANISM for Coomer services
      int maxRetries = (effectiveApiSource == ApiSource.coomer)
          ? 5
          : 2; // More retries for Coomer
      int retryCount = 0;

      while (retryCount <= maxRetries) {
        try {
          final newPosts = await repository.getCreatorPosts(
            service,
            creatorId,
            offset: _offset,
            apiSource: effectiveApiSource,
          );

          if (newPosts.isEmpty) {
            _hasMore = false;
            // Don't set error for empty posts - this is normal for creators with no posts
          } else {
            _posts.addAll(newPosts);
            _offset += newPosts.length;
          }

          // Success - break the retry loop
          break;
        } catch (e) {
          retryCount++;

          if (retryCount > maxRetries) {
            // Final attempt failed - set error
            _error = _getErrorMessage(e, effectiveApiSource, retryCount);
            break;
          }

          // Exponential backoff for Coomer, linear for others
          int delayMs = (effectiveApiSource == ApiSource.coomer)
              ? 1000 *
                    (1 << (retryCount - 1)) // 1s, 2s, 4s, 8s, 16s
              : 500 * retryCount; // 0.5s, 1s, 1.5s

          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    } catch (e) {
      _error = _getErrorMessage(e, _currentApiSource ?? ApiSource.kemono, 99);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // HELPER METHOD - User-friendly error messages
  String _getErrorMessage(
    dynamic error,
    ApiSource apiSource,
    int attemptCount,
  ) {
    final errorString = error.toString().toLowerCase();

    if (apiSource == ApiSource.coomer) {
      if (errorString.contains('timeout') ||
          errorString.contains('connection')) {
        return 'Coomer servers are slow. Auto-retrying... (attempt $attemptCount)';
      } else if (errorString.contains('404') ||
          errorString.contains('not found')) {
        return 'Creator not found on Coomer servers';
      } else if (errorString.contains('503') ||
          errorString.contains('unavailable')) {
        return 'Coomer servers temporarily unavailable. Auto-retrying...';
      } else if (errorString.contains('socket') ||
          errorString.contains('network')) {
        return 'Network issue with Coomer. Auto-retrying...';
      } else {
        return 'Coomer server error. Auto-retry will fix this automatically';
      }
    } else {
      if (errorString.contains('timeout')) {
        return 'Connection timeout. Auto-retrying... (attempt $attemptCount)';
      } else if (errorString.contains('404')) {
        return 'Content not found';
      } else if (errorString.contains('503') ||
          errorString.contains('unavailable')) {
        return 'Server temporarily unavailable. Auto-retrying...';
      } else if (errorString.contains('socket') ||
          errorString.contains('network')) {
        return 'Network connection issue. Auto-retrying...';
      } else {
        return 'Loading error. Auto-retrying... (attempt $attemptCount)';
      }
    }
  }

  Future<void> searchPosts(String query, {bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _posts.clear(); // Clear existing posts to prevent memory leak
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newPosts = await repository.searchPosts(
        query,
        offset: _offset,
        limit: 50,
        apiSource: settingsProvider.defaultApiSource,
      );
      _currentApiSource = settingsProvider.defaultApiSource;

      if (newPosts.isEmpty) {
        _hasMore = false;
      } else {
        _posts.addAll(newPosts);
        _offset += newPosts.length;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLatestPosts({
    bool refresh = false,
    String filter = 'latest',
    ApiSource? apiSource,
  }) async {
    if (refresh) {
      _offset = 0;
      _posts.clear(); // Clear existing posts to prevent memory leak
      _hasMore = true;
    }

    if (_isLoading || (!_hasMore && !refresh)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use provided apiSource or fallback to settings
      final effectiveApiSource = apiSource ?? settingsProvider.defaultApiSource;
      _currentApiSource = effectiveApiSource;

      // Enhanced logging for debugging

      // Force clear cache when switching API sources
      if (apiSource != null && apiSource != _currentApiSource) {
        _posts.clear();
        _offset = 0;
        _hasMore = true;
      }

      // ENHANCED AUTO-RETRY MECHANISM for Latest Posts
      int maxRetries = (effectiveApiSource == ApiSource.coomer)
          ? 6
          : 3; // Increased retries
      int retryCount = 0;
      bool shouldRetry = true;

      while (shouldRetry && retryCount <= maxRetries) {
        try {
          AppLogger.debug(
            '🔍 DEBUG: Attempting to load latest posts (attempt ${retryCount + 1}/${maxRetries + 1})',
          );

          // Use different query based on filter
          String query;
          switch (filter) {
            case 'random':
              query = ''; // Empty query with random order
              break;
            case 'popular':
              query = 'sort:popular'; // Try popular sort
              break;
            default:
              query = ' '; // Space for all posts (latest)
          }

          final newPosts = await repository.searchPosts(
            query,
            offset: _offset,
            limit: 50,
            apiSource: effectiveApiSource,
          );
          AppLogger.debug(
            '🔍 DEBUG: Repository returned ${newPosts.length} latest posts',
          );

          if (newPosts.isEmpty) {
            _hasMore = false;
            AppLogger.debug(
              '🔍 DEBUG: No more latest posts available, setting _hasMore to false',
            );
          } else {
            _posts.addAll(newPosts);
            _offset += newPosts.length;
            AppLogger.debug(
              '🔍 DEBUG: Added ${newPosts.length} latest posts, total now: ${_posts.length}',
            );
          }

          // Success - clear error and break the retry loop
          _error = null;
          shouldRetry = false;
          AppLogger.debug('🔍 DEBUG: Success! Breaking retry loop');
          break;
        } catch (e) {
          retryCount++;
          AppLogger.debug(
            '🔍 DEBUG: Latest posts load attempt $retryCount failed: $e',
          );

          // Check if we should continue retrying
          if (retryCount > maxRetries) {
            // Final attempt failed - set user-friendly error
            _error = _getErrorMessage(e, effectiveApiSource, retryCount);
            AppLogger.debug(
              '🔍 DEBUG: All latest posts retry attempts failed, setting error: $_error',
            );
            shouldRetry = false;
            break;
          }

          // Check if error is retryable
          final errorString = e.toString().toLowerCase();
          final isRetryable =
              errorString.contains('timeout') ||
              errorString.contains('connection') ||
              errorString.contains('503') ||
              errorString.contains('unavailable') ||
              (effectiveApiSource == ApiSource.coomer); // Always retry Coomer

          if (!isRetryable) {
            _error = _getErrorMessage(e, effectiveApiSource, retryCount);
            AppLogger.debug(
              '🔍 DEBUG: Non-retryable error, stopping retries: $_error',
            );
            shouldRetry = false;
            break;
          }

          // Enhanced backoff: exponential for Coomer, linear for others
          int delayMs;
          if (effectiveApiSource == ApiSource.coomer) {
            delayMs =
                1000 * (1 << (retryCount - 1)); // 1s, 2s, 4s, 8s, 16s, 32s
          } else {
            delayMs = 500 * retryCount; // 0.5s, 1s, 1.5s, 2s, 2.5s
          }

          // Cap delay at 10 seconds
          delayMs = delayMs.clamp(0, 10000);

          await Future.delayed(Duration(milliseconds: delayMs));

          // Update UI with retry status
          if (retryCount <= 2) {
            // Only show first few retries
            _error = 'Loading... (retry $retryCount/$maxRetries)';
            notifyListeners();
          }
        }
      }
    } catch (e) {
      _error = _getErrorMessage(e, _currentApiSource ?? ApiSource.kemono, 99);
      AppLogger.debug('🔍 DEBUG: Final error in loadLatestPosts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Use empty query to get more latest posts
      final newPosts = await repository.searchPosts(
        ' ',
        offset: _offset,
        limit: 50,
        apiSource: settingsProvider.defaultApiSource,
      );

      if (newPosts.isEmpty) {
        _hasMore = false;
      } else {
        _posts.addAll(newPosts);
        _offset += newPosts.length;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchByTags(List<String> tags, {bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _posts.clear(); // Clear existing posts to prevent memory leak
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newPosts = await repository.getPostsByTags(
        tags,
        offset: _offset,
        apiSource: settingsProvider.defaultApiSource,
      );
      _currentApiSource = settingsProvider.defaultApiSource;

      if (newPosts.isEmpty) {
        _hasMore = false;
      } else {
        _posts.addAll(newPosts);
        _offset += newPosts.length;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int get retryCount => _retryCount;
  bool get canRetry => _retryCount < _maxRetries && _error != null;

  void reset() {
    _posts.clear(); // Clear existing posts to prevent memory leak
    _isLoading = false;
    _hasMore = true;
    _error = null;
    _offset = 0;
    _currentApiSource = null;
    _retryCount = 0;
    notifyListeners();
  }

  void clearPosts() {
    _posts.clear();
    _offset = 0;
    _hasMore = true;
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
      // Check actual state from saved posts list instead of post.saved
      final isCurrentlySaved = _savedPosts.any((p) => p.id == post.id);

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
      final savedIndex = _savedPosts.indexWhere((p) => p.id == post.id);
      if (isCurrentlySaved) {
        // Post was saved, now unsaved - remove from saved posts
        if (savedIndex != -1) {
          _savedPosts.removeAt(savedIndex);
        }
      } else {
        // Post was unsaved, now saved - add to saved posts
        if (savedIndex == -1) {
          _savedPosts.insert(0, post.copyWith(saved: true)); // Add to beginning
        }
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

      // ENHANCED AUTO-RETRY MECHANISM for Single Post
      int maxRetries = (effectiveApiSource == ApiSource.coomer)
          ? 6
          : 3; // Same as latest posts
      int retryCount = 0;
      bool shouldRetry = true;

      while (shouldRetry && retryCount <= maxRetries) {
        try {
          AppLogger.debug(
            '🔍 DEBUG: Attempting to load single post (attempt ${retryCount + 1}/${maxRetries + 1})',
          );

          final post = await repository.getPost(
            service,
            creatorId,
            postId,
            apiSource: effectiveApiSource,
          );
          AppLogger.debug(
            '🔍 DEBUG: Repository returned single post: ${post.id}',
          );

          // Replace or add the post to the current list
          final existingIndex = _posts.indexWhere((p) => p.id == postId);
          if (existingIndex != -1) {
            _posts[existingIndex] = post; // Replace existing post
          } else {
            _posts.insert(0, post); // Add to beginning if not exists
          }

          // Success - clear error and break the retry loop
          _error = null;
          shouldRetry = false;
          AppLogger.debug(
            '🔍 DEBUG: Single post loaded successfully! Breaking retry loop',
          );
          debugPrint(
            'PostsProvider: Single post loaded successfully - ${post.id}',
          );
          break;
        } catch (e) {
          retryCount++;
          AppLogger.debug(
            '🔍 DEBUG: Single post load attempt $retryCount failed: $e',
          );

          // Check if we should continue retrying
          if (retryCount > maxRetries) {
            // Final attempt failed - set user-friendly error
            _error = _getErrorMessage(e, effectiveApiSource, retryCount);
            AppLogger.debug(
              '🔍 DEBUG: All single post retry attempts failed, setting error: $_error',
            );
            shouldRetry = false;
            break;
          }

          // Check if error is retryable
          final errorString = e.toString().toLowerCase();
          final isRetryable =
              errorString.contains('timeout') ||
              errorString.contains('connection') ||
              errorString.contains('503') ||
              errorString.contains('unavailable') ||
              (effectiveApiSource == ApiSource.coomer); // Always retry Coomer

          if (!isRetryable) {
            _error = _getErrorMessage(e, effectiveApiSource, retryCount);
            AppLogger.debug(
              '🔍 DEBUG: Non-retryable error, stopping retries: $_error',
            );
            shouldRetry = false;
            break;
          }

          // Enhanced backoff: exponential for Coomer, linear for others
          int delayMs;
          if (effectiveApiSource == ApiSource.coomer) {
            delayMs =
                1000 * (1 << (retryCount - 1)); // 1s, 2s, 4s, 8s, 16s, 32s
          } else {
            delayMs = 500 * retryCount; // 0.5s, 1s, 1.5s, 2s, 2.5s
          }

          // Cap delay at 10 seconds
          delayMs = delayMs.clamp(0, 10000);

          await Future.delayed(Duration(milliseconds: delayMs));

          // Update UI with retry status
          if (retryCount <= 2) {
            // Only show first few retries
            _error = 'Loading post... (retry $retryCount/$maxRetries)';
            notifyListeners();
          }
        }
      }
    } catch (e) {
      _error = _getErrorMessage(e, _currentApiSource ?? ApiSource.kemono, 99);
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

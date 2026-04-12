import 'package:flutter/foundation.dart';

import '../../data/utils/api_response_utils.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../utils/logger.dart';
import 'settings_provider.dart';

/// Standalone API handler for the Creator Detail screen.
///
/// Keeps its own [_isLoading], [_error], [_offset], [_hasMore], and
/// [_generation] so it is completely isolated from [LatestPostsApiHandler]
/// and [PostDetailApiHandler]. Each [CreatorDetailScreen] instance creates its
/// own handler, so multiple creator screens on the navigation stack never
/// interfere with each other or with the latest-posts feed.
class CreatorDetailApiHandler extends ChangeNotifier {
  final KemonoRepository repository;
  final SettingsProvider settingsProvider;

  CreatorDetailApiHandler({
    required this.repository,
    required this.settingsProvider,
  });

  // ── Own isolated state ────────────────────────────────────────────────────

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  ApiSource? _currentApiSource;

  /// Generation counter – incremented whenever the handler is cleared or
  /// refreshed so stale in-flight responses are silently discarded.
  int _generation = 0;

  // ── Public getters ────────────────────────────────────────────────────────

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  ApiSource? get currentApiSource => _currentApiSource;

  // ── Public actions ────────────────────────────────────────────────────────

  /// Clear all posts and reset pagination. Call before loading a new creator.
  void clear() {
    _generation++;
    _posts = [];
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Load creator posts.
  ///
  /// Pass [refresh]=true to reset pagination and start from the beginning.
  Future<void> loadCreatorPosts(
    String service,
    String creatorId, {
    bool refresh = false,
    ApiSource? apiSource,
  }) async {
    AppLogger.debug(
      'CreatorDetailApiHandler.loadCreatorPosts: service=$service, '
      'id=$creatorId, refresh=$refresh',
    );

    if (refresh) {
      _generation++;
      _offset = 0;
      _posts = [];
      _hasMore = true;
      _isLoading = false;
      _error = null;
    }

    if (_isLoading || !_hasMore) {
      AppLogger.debug(
        'CreatorDetailApiHandler: already loading or no more posts – returning',
      );
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _generation;
    final effectiveApiSource = apiSource ?? _apiSourceForService(service);
    _currentApiSource = effectiveApiSource;
    // Keep retry counts low: the inner RetryHttpClient already retries at the
    // HTTP layer, so a high outer count multiplies the total wait time.
    final maxRetries = effectiveApiSource == ApiSource.coomer ? 2 : 1;

    try {
      await ApiResponseUtils.withRetry(
        () async {
          try {
            final newPosts = await repository.getCreatorPosts(
              service,
              creatorId,
              offset: _offset,
              apiSource: effectiveApiSource,
            );

            if (_generation != generation) {
              AppLogger.debug(
                'CreatorDetailApiHandler: discarding stale result (generation mismatch)',
              );
              return;
            }

            if (newPosts.isEmpty) {
              _hasMore = false;
              return;
            }

            _posts.addAll(newPosts);
            _offset += newPosts.length;
          } catch (e) {
            if (!_isRetryableError(e, effectiveApiSource)) {
              throw ApiResponseUtils.nonRetryable(e);
            }
            rethrow;
          }
        },
        maxRetries: maxRetries,
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt),
      );
    } catch (e) {
      if (_generation == generation) {
        _error = _errorMessage(e, effectiveApiSource);
      }
    } finally {
      if (_generation == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  ApiSource _apiSourceForService(String service) {
    switch (service.toLowerCase()) {
      case 'onlyfans':
      case 'fansly':
      case 'candfans':
        return ApiSource.coomer;
      default:
        return ApiSource.kemono;
    }
  }

  bool _isRetryableError(Object error, ApiSource apiSource) {
    if (apiSource == ApiSource.coomer) return true;
    final s = error.toString().toLowerCase();
    return s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('503') ||
        s.contains('unavailable') ||
        s.contains('socket') ||
        s.contains('network');
  }

  Duration _retryDelay(ApiSource apiSource, int attempt) {
    final ms = apiSource == ApiSource.coomer
        ? 1000 * (1 << attempt)
        : 500 * (attempt + 1);
    return Duration(milliseconds: ms.clamp(0, 10000));
  }

  String _errorMessage(dynamic error, ApiSource apiSource) {
    final s = error.toString().toLowerCase();
    if (apiSource == ApiSource.coomer) {
      if (s.contains('timeout') || s.contains('connection')) {
        return 'Coomer servers are slow. Please tap Retry to try again.';
      } else if (s.contains('404') || s.contains('not found')) {
        return 'Creator not found on Coomer servers';
      } else if (s.contains('503') || s.contains('unavailable')) {
        return 'Coomer servers temporarily unavailable. Please tap Retry to try again.';
      } else if (s.contains('socket') || s.contains('network')) {
        return 'Network issue with Coomer. Please tap Retry to try again.';
      } else {
        return 'Coomer server error. Please tap Retry to try again.';
      }
    } else {
      if (s.contains('timeout')) {
        return 'Connection timeout. Please tap Retry to try again.';
      } else if (s.contains('404')) {
        return 'Content not found';
      } else if (s.contains('503') || s.contains('unavailable')) {
        return 'Server temporarily unavailable. Please tap Retry to try again.';
      } else if (s.contains('socket') || s.contains('network')) {
        return 'Network connection issue. Please tap Retry to try again.';
      } else {
        return 'Loading error. Please tap Retry to try again.';
      }
    }
  }
}

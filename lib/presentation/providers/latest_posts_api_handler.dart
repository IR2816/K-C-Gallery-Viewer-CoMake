import 'package:flutter/foundation.dart';

import '../../data/utils/api_response_utils.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../utils/logger.dart';
import 'settings_provider.dart';

/// Standalone API handler for the Latest Posts feed.
///
/// Keeps its own [_isLoading], [_error], [_offset], [_hasMore], and
/// [_generation] so it is completely isolated from [CreatorDetailApiHandler]
/// and [PostDetailApiHandler]. Navigating between screens can never corrupt
/// this handler's pagination state or interfere with its in-flight requests.
class LatestPostsApiHandler extends ChangeNotifier {
  final KemonoRepository repository;
  final SettingsProvider settingsProvider;

  LatestPostsApiHandler({
    required this.repository,
    required this.settingsProvider,
  });

  // ── Own isolated state ────────────────────────────────────────────────────

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  ApiSource? _apiSource;

  /// Generation counter – incremented on every fresh load so stale in-flight
  /// responses from a cancelled session are silently discarded.
  int _generation = 0;

  // ── Public getters ────────────────────────────────────────────────────────

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  /// The API source that was locked when [loadInitial] was last called.
  /// Use this (not [settingsProvider]) to decide whether a feed reload is
  /// necessary after a settings change.
  ApiSource? get apiSource => _apiSource;

  // ── Public actions ────────────────────────────────────────────────────────

  /// Load (or refresh) the first page of the latest-posts feed.
  Future<void> loadInitial({ApiSource? apiSource}) async {
    _generation++;
    _offset = 0;
    _posts = [];
    _hasMore = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _generation;
    final effectiveApiSource = apiSource ?? settingsProvider.defaultApiSource;
    _apiSource = effectiveApiSource;
    final maxRetries = effectiveApiSource == ApiSource.coomer ? 2 : 1;

    try {
      AppLogger.debug(
        'LatestPostsApiHandler: loadInitial – api=${effectiveApiSource.name}',
      );

      await ApiResponseUtils.withRetry(
        () async {
          try {
            final newPosts = await repository.searchPosts(
              ' ',
              offset: 0,
              limit: 50,
              apiSource: effectiveApiSource,
            );

            if (_generation != generation) {
              AppLogger.debug(
                'LatestPostsApiHandler: discarding stale loadInitial result',
              );
              return;
            }

            if (newPosts.isEmpty) {
              _hasMore = false;
            } else {
              _posts = List<Post>.from(newPosts);
              _offset = newPosts.length;
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
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt),
      );
    } catch (e) {
      if (_generation == generation) {
        _error =
            'Failed to load latest posts. Please try again or switch API in Settings.';
        AppLogger.debug('LatestPostsApiHandler: loadInitial error: $e');
      }
    } finally {
      if (_generation == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Load the next page of the feed (infinite scroll).
  ///
  /// Uses the API source locked during [loadInitial] so the source never
  /// changes mid-session.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    final effectiveApiSource = _apiSource ?? settingsProvider.defaultApiSource;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final generation = _generation;
    final maxRetries = effectiveApiSource == ApiSource.coomer ? 2 : 1;

    try {
      AppLogger.debug(
        'LatestPostsApiHandler: loadMore – offset=$_offset, api=${effectiveApiSource.name}',
      );

      await ApiResponseUtils.withRetry(
        () async {
          try {
            final newPosts = await repository.searchPosts(
              ' ',
              offset: _offset,
              limit: 50,
              apiSource: effectiveApiSource,
            );

            if (_generation != generation) {
              AppLogger.debug(
                'LatestPostsApiHandler: discarding stale loadMore result',
              );
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
        delay: (attempt) => _retryDelay(effectiveApiSource, attempt),
      );
    } catch (e) {
      if (_generation == generation) {
        _error = 'Failed to load more posts. Please try again.';
        AppLogger.debug('LatestPostsApiHandler: loadMore error: $e');
      }
    } finally {
      if (_generation == generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

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
}

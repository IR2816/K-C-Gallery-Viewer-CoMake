import 'package:flutter/foundation.dart';

import '../../data/utils/api_response_utils.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../utils/logger.dart';

/// Standalone API handler for the Post Detail screen.
///
/// Keeps its own [_isLoading] and [_error] so it is completely isolated from
/// [LatestPostsApiHandler] and [CreatorDetailApiHandler]. Each
/// [PostDetailScreen] instance creates its own handler, preventing any
/// cross-screen state contamination when loading a single post's full content.
class PostDetailApiHandler extends ChangeNotifier {
  final KemonoRepository repository;

  PostDetailApiHandler({required this.repository});

  // ── Own isolated state ────────────────────────────────────────────────────

  bool _isLoading = false;
  String? _error;
  Post? _post;

  // ── Public getters ────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  Post? get post => _post;

  // ── Public actions ────────────────────────────────────────────────────────

  /// Load a single post's full data from the API.
  Future<void> loadSinglePost(
    String service,
    String creatorId,
    String postId, {
    ApiSource? apiSource,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final effectiveApiSource = apiSource ?? _apiSourceForService(service);
    AppLogger.debug(
      'PostDetailApiHandler: loading post $postId, api=${effectiveApiSource.name}',
    );

    const maxRetries = 3;

    try {
      await ApiResponseUtils.withRetry(
        () async {
          try {
            final post = await repository.getPost(
              service,
              creatorId,
              postId,
              apiSource: effectiveApiSource,
            );
            _post = post;
            _error = null;
          } catch (e) {
            if (!_isRetryableError(e, effectiveApiSource)) {
              throw ApiResponseUtils.nonRetryable(e);
            }
            rethrow;
          }
        },
        maxRetries: maxRetries,
        delay: (attempt) => _retryDelay(attempt),
      );
    } catch (e) {
      if (e is NonRetryableException) {
        _error = 'Error: ${e.cause.runtimeType} - ${e.cause}';
      } else {
        _error = 'Error: ${e.runtimeType} - $e';
      }
      AppLogger.debug('PostDetailApiHandler: error loading post: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
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
        s.contains('429') ||
        s.contains('rate limit') ||
        s.contains('unavailable') ||
        s.contains('socket') ||
        s.contains('network');
  }

  Duration _retryDelay(int attempt) {
    final ms = 800 * (1 << attempt);
    return Duration(milliseconds: ms.clamp(0, 8000));
  }
}

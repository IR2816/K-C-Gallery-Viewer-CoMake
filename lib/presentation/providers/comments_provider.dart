import 'package:flutter/foundation.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../utils/logger.dart';

class CommentsProvider with ChangeNotifier {
  final KemonoRepository repository;

  CommentsProvider({required this.repository});

  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _error;
  String? _currentPostId;
  String? _currentService;

  List<Comment> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentPostId => _currentPostId;
  String? get currentService => _currentService;
  int get commentCount => _comments.length;

  Future<void> loadComments(
    String postId,
    String service,
    String creatorId,
  ) async {
    // Always reload for different posts - fix state sticking issue
    if (_currentPostId != postId || _currentService != service) {
      AppLogger.debug('New post detected, clearing previous comments', tag: 'Comments');
      _comments.clear();
    }

    // Don't reload if same post and already loaded
    if (_currentPostId == postId &&
        _currentService == service &&
        _comments.isNotEmpty) {
      AppLogger.debug('Same post already loaded, skipping reload', tag: 'Comments');
      return;
    }

    _currentPostId = postId;
    _currentService = service;
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify immediately to update preview

    try {
      AppLogger.debug(
        'Loading comments for postId: $postId, service: $service, creatorId: $creatorId',
        tag: 'Comments',
      );
      _comments = await repository.getComments(postId, service, creatorId);
      AppLogger.info('Loaded ${_comments.length} comments', tag: 'Comments');
      _error = null;
    } catch (e) {
      AppLogger.error('Error loading comments', tag: 'Comments', error: e);
      _error = e.toString();
      _comments = [];
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify again with loaded data
    }
  }

  void clearComments() {
    _comments.clear();
    _currentPostId = null;
    _currentService = null;
    _error = null;
    notifyListeners();
  }

  String getLatestCommentPreview() {
    if (_comments.isEmpty) return '';
    final latest = _comments.first;
    final content = latest.content.length > 50
        ? '${latest.content.substring(0, 50)}...'
        : latest.content;
    return '${latest.username}: $content';
  }

  void refresh() {
    if (_currentPostId != null && _currentService != null) {
      // We need creatorId for refresh, but we don't store it
      // This is a limitation - we'll need to store creatorId as well
      // For now, just return
      return;
    }
  }
}

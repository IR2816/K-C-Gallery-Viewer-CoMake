import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_bookmark.dart';

enum BookmarkSortOrder { dateBookmarkedDesc, dateBookmarkedAsc, creatorAZ, ratingDesc }

class BookmarkProvider with ChangeNotifier {
  static const _prefsKey = 'post_bookmarks_v1';

  final List<PostBookmark> _bookmarks = [];
  bool _initialized = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get initialized => _initialized;
  int get count => _bookmarks.length;

  List<PostBookmark> get bookmarks => List.unmodifiable(_bookmarks);

  bool isBookmarked(String postId) =>
      _bookmarks.any((b) => b.postId == postId);

  PostBookmark? getForPost(String postId) {
    try {
      return _bookmarks.firstWhere((b) => b.postId == postId);
    } catch (_) {
      return null;
    }
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
    notifyListeners();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Adds a bookmark for [post] with optional annotations.
  /// If already bookmarked, returns the existing bookmark without duplication.
  Future<PostBookmark> addBookmark(
    Post post, {
    String notes = '',
    int? rating,
    List<String> tags = const [],
    String? thumbnailUrl,
  }) async {
    final existing = getForPost(post.id);
    if (existing != null) return existing;

    // Count media
    final mediaCount = post.attachments.length +
        post.file.length +
        (post.embedUrl != null ? 1 : 0);

    final bookmark = PostBookmark(
      id: '${post.id}_${DateTime.now().millisecondsSinceEpoch}',
      postId: post.id,
      creatorName: post.user,
      service: post.service,
      title: post.title.isNotEmpty ? post.title : '(untitled)',
      content: post.content,
      published: post.published,
      personalNotes: notes,
      rating: rating,
      tags: tags.take(5).toList(),
      bookmarkedDate: DateTime.now(),
      mediaCount: mediaCount,
      thumbnailUrl: thumbnailUrl,
    );

    _bookmarks.insert(0, bookmark);
    await _save();
    notifyListeners();
    return bookmark;
  }

  /// Removes the bookmark for the given [postId].
  Future<void> removeBookmark(String postId) async {
    _bookmarks.removeWhere((b) => b.postId == postId);
    await _save();
    notifyListeners();
  }

  /// Re-inserts a previously-removed bookmark (used for undo support).
  Future<void> restoreBookmark(PostBookmark bookmark) async {
    if (_bookmarks.any((b) => b.id == bookmark.id)) return;
    _bookmarks.insert(0, bookmark);
    await _save();
    notifyListeners();
  }

  /// Replaces an existing bookmark (identified by id) with [updated].
  Future<void> updateBookmark(PostBookmark updated) async {
    final idx = _bookmarks.indexWhere((b) => b.id == updated.id);
    if (idx == -1) return;
    _bookmarks[idx] = updated;
    await _save();
    notifyListeners();
  }

  // ── Query helpers ──────────────────────────────────────────────────────────

  List<PostBookmark> searchBookmarks(String query) {
    if (query.isEmpty) return List.unmodifiable(_bookmarks);
    final q = query.toLowerCase();
    return _bookmarks.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.content.toLowerCase().contains(q) ||
          b.creatorName.toLowerCase().contains(q) ||
          b.personalNotes.toLowerCase().contains(q) ||
          b.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<PostBookmark> filterByCreator(String creatorName) =>
      _bookmarks.where((b) => b.creatorName == creatorName).toList();

  List<PostBookmark> filterByTags(List<String> tags) {
    if (tags.isEmpty) return List.unmodifiable(_bookmarks);
    return _bookmarks
        .where((b) => tags.every((t) => b.tags.contains(t)))
        .toList();
  }

  List<String> get allCreators {
    final creators = _bookmarks.map((b) => b.creatorName).toSet().toList()
      ..sort();
    return creators;
  }

  List<PostBookmark> sorted(BookmarkSortOrder order) {
    final list = List<PostBookmark>.from(_bookmarks);
    switch (order) {
      case BookmarkSortOrder.dateBookmarkedDesc:
        list.sort((a, b) => b.bookmarkedDate.compareTo(a.bookmarkedDate));
      case BookmarkSortOrder.dateBookmarkedAsc:
        list.sort((a, b) => a.bookmarkedDate.compareTo(b.bookmarkedDate));
      case BookmarkSortOrder.creatorAZ:
        list.sort((a, b) => a.creatorName.compareTo(b.creatorName));
      case BookmarkSortOrder.ratingDesc:
        list.sort((a, b) {
          final ra = a.rating ?? 0;
          final rb = b.rating ?? 0;
          return rb.compareTo(ra);
        });
    }
    return list;
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];
      _bookmarks.clear();
      for (final s in raw) {
        try {
          _bookmarks.add(PostBookmark.fromJsonString(s));
        } catch (e) {
          debugPrint('BookmarkProvider: skipping corrupt entry – $e');
        }
      }
    } catch (e) {
      debugPrint('BookmarkProvider: load error – $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        _bookmarks.map((b) => b.toJsonString()).toList(),
      );
    } catch (e) {
      debugPrint('BookmarkProvider: save error – $e');
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/creator.dart';

/// Lightweight DTO used for persisting creator quick-access entries.
class _CreatorEntry {
  final String id;
  final String service;
  final String name;
  final int indexed;
  final int updated;

  const _CreatorEntry({
    required this.id,
    required this.service,
    required this.name,
    required this.indexed,
    required this.updated,
  });

  Creator toCreator() => Creator(
    id: id,
    service: service,
    name: name,
    indexed: indexed,
    updated: updated,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'service': service,
    'name': name,
    'indexed': indexed,
    'updated': updated,
  };

  factory _CreatorEntry.fromJson(Map<String, dynamic> json) => _CreatorEntry(
    id: json['id'] as String? ?? '',
    service: json['service'] as String? ?? '',
    name: json['name'] as String? ?? '',
    indexed: (json['indexed'] as num?)?.toInt() ?? 0,
    updated: (json['updated'] as num?)?.toInt() ?? 0,
  );

  factory _CreatorEntry.fromCreator(Creator creator) => _CreatorEntry(
    id: creator.id,
    service: creator.service,
    name: creator.name,
    indexed: creator.indexed,
    updated: creator.updated,
  );
}

/// Provides quick access to recently-viewed and locally-favorited creators.
///
/// All data is stored in [SharedPreferences] so it persists across app
/// restarts without requiring a network connection.
class CreatorQuickAccessProvider with ChangeNotifier {
  static const _recentKey = 'creator_quick_access_recent_v1';
  static const _favKey = 'creator_quick_access_favorites_v1';
  static const _defaultRecentLimit = 10;

  final List<_CreatorEntry> _recent = [];
  final List<_CreatorEntry> _favorites = [];
  bool _initialized = false;

  bool get initialized => _initialized;

  // ── Public Queries ────────────────────────────────────────────────────────

  /// Returns the last [limit] viewed creators, most-recent first.
  List<Creator> getRecentCreators({int limit = _defaultRecentLimit}) {
    final end = limit.clamp(0, _recent.length);
    return _recent.sublist(0, end).map((e) => e.toCreator()).toList();
  }

  /// Returns all locally-favorited creators.
  List<Creator> getFavoriteCreators() =>
      _favorites.map((e) => e.toCreator()).toList();

  /// Returns [true] if the creator with [creatorId] is locally favorited.
  bool isFavorite(String creatorId) => _favorites.any((e) => e.id == creatorId);

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Records that the user viewed [creator].
  ///
  /// The creator is moved to the front of the recent list; duplicates are
  /// de-duplicated by [id].
  Future<void> addRecentCreator(Creator creator) async {
    _recent.removeWhere((e) => e.id == creator.id);
    _recent.insert(0, _CreatorEntry.fromCreator(creator));
    // Keep at most 50 entries to avoid unbounded growth
    if (_recent.length > 50) _recent.removeRange(50, _recent.length);
    await _saveRecent();
    notifyListeners();
  }

  /// Adds [creator] to the local favorites list.
  ///
  /// If the creator is already in favorites, this is a no-op.
  Future<void> addFavoriteCreator(Creator creator) async {
    if (isFavorite(creator.id)) return;
    _favorites.add(_CreatorEntry.fromCreator(creator));
    await _saveFavorites();
    notifyListeners();
  }

  /// Removes the creator identified by [creatorId] from local favorites.
  Future<void> removeFavoriteCreator(String creatorId) async {
    _favorites.removeWhere((e) => e.id == creatorId);
    await _saveFavorites();
    notifyListeners();
  }

  /// Toggles the favorite state for [creator].
  Future<void> toggleFavoriteCreator(Creator creator) async {
    if (isFavorite(creator.id)) {
      await removeFavoriteCreator(creator.id);
    } else {
      await addFavoriteCreator(creator);
    }
  }

  /// Searches favorites by name (case-insensitive).
  List<Creator> searchFavorites(String query) {
    if (query.trim().isEmpty) return getFavoriteCreators();
    final q = query.toLowerCase();
    return _favorites
        .where((e) => e.name.toLowerCase().contains(q))
        .map((e) => e.toCreator())
        .toList();
  }

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    await _loadRecent();
    await _loadFavorites();
    _initialized = true;
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentKey) ?? [];
      _recent.clear();
      for (final s in raw) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          _recent.add(_CreatorEntry.fromJson(map));
        } catch (e) {
          debugPrint(
            'CreatorQuickAccessProvider: skipping corrupt recent – $e',
          );
        }
      }
    } catch (e) {
      debugPrint('CreatorQuickAccessProvider: load recent error – $e');
    }
  }

  Future<void> _saveRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recentKey,
        _recent.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('CreatorQuickAccessProvider: save recent error – $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_favKey) ?? [];
      _favorites.clear();
      for (final s in raw) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          _favorites.add(_CreatorEntry.fromJson(map));
        } catch (e) {
          debugPrint(
            'CreatorQuickAccessProvider: skipping corrupt favorite – $e',
          );
        }
      }
    } catch (e) {
      debugPrint('CreatorQuickAccessProvider: load favorites error – $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _favKey,
        _favorites.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('CreatorQuickAccessProvider: save favorites error – $e');
    }
  }
}

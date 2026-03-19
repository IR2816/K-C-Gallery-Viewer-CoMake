import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single search history entry with metadata.
class SearchHistoryEntry {
  final String query;
  final String type; // 'creator' or 'post'
  final DateTime timestamp;
  final int frequency; // Number of times searched

  const SearchHistoryEntry({
    required this.query,
    required this.type,
    required this.timestamp,
    this.frequency = 1,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'frequency': frequency,
  };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) => SearchHistoryEntry(
    query: json['query'] as String? ?? '',
    type: json['type'] as String? ?? 'creator',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    frequency: json['frequency'] as int? ?? 1,
  );

  SearchHistoryEntry copyWith({String? query, String? type, DateTime? timestamp, int? frequency}) =>
      SearchHistoryEntry(
        query: query ?? this.query,
        type: type ?? this.type,
        timestamp: timestamp ?? this.timestamp,
        frequency: frequency ?? this.frequency,
      );
}

/// Manages search history with type-aware tracking and frequency counting.
///
/// Features:
/// - Track searches by type ('creator' or 'post')
/// - Count frequency of searches
/// - Persist to SharedPreferences
/// - Retrieve by type or across all types
/// - Clear individual or all entries
/// - Get suggestions based on query prefix
class SearchHistoryProvider with ChangeNotifier {
  static const _historyKey = 'search_history_v2';
  static const _maxEntries = 50;

  final List<SearchHistoryEntry> _history = [];
  bool _enabled = true;

  List<SearchHistoryEntry> get history => _history;
  bool get enabled => _enabled;

  // ── Public Queries ────────────────────────────────────────────────────────

  /// Get all searches, optionally filtered by type.
  List<SearchHistoryEntry> getSearchHistory({String? type, int limit = 20}) {
    var results = _history;
    if (type != null) {
      results = results.where((e) => e.type == type).toList();
    }
    return results.take(limit).toList();
  }

  /// Get search suggestions by matching query prefix.
  List<SearchHistoryEntry> getSuggestions(String query, {String? type}) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    var results = _history.where((e) => e.query.toLowerCase().startsWith(q)).toList();
    if (type != null) {
      results = results.where((e) => e.type == type).toList();
    }
    return results;
  }

  /// Get most frequently searched items.
  List<SearchHistoryEntry> getMostFrequent({String? type, int limit = 10}) {
    var results = _history;
    if (type != null) {
      results = results.where((e) => e.type == type).toList();
    }
    results.sort((a, b) => b.frequency.compareTo(a.frequency));
    return results.take(limit).toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Record a search query with type and timestamp.
  Future<void> trackSearch(String query, {String type = 'creator'}) async {
    if (!_enabled || query.trim().isEmpty) return;

    final trimmed = query.trim();

    // Find existing entry
    final index = _history.indexWhere(
      (e) => e.query.toLowerCase() == trimmed.toLowerCase() && e.type == type,
    );

    if (index >= 0) {
      // Update frequency and move to top
      final entry = _history[index];
      _history.removeAt(index);
      _history.insert(0, entry.copyWith(timestamp: DateTime.now(), frequency: entry.frequency + 1));
    } else {
      // Add new entry
      _history.insert(
        0,
        SearchHistoryEntry(query: trimmed, type: type, timestamp: DateTime.now(), frequency: 1),
      );
    }

    // Trim to max entries
    if (_history.length > _maxEntries) {
      _history.removeRange(_maxEntries, _history.length);
    }

    await _save();
    notifyListeners();
  }

  /// Remove a specific search from history.
  Future<void> removeFromHistory(String query, {String? type}) async {
    _history.removeWhere((e) {
      final matches = e.query.toLowerCase() == query.toLowerCase();
      if (type != null) return matches && e.type == type;
      return matches;
    });
    await _save();
    notifyListeners();
  }

  /// Clear all search history.
  Future<void> clearSearchHistory() async {
    _history.clear();
    await _save();
    notifyListeners();
  }

  /// Clear history of a specific type.
  Future<void> clearByType(String type) async {
    _history.removeWhere((e) => e.type == type);
    await _save();
    notifyListeners();
  }

  /// Enable or disable search history tracking.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('search_history_enabled', enabled);
    notifyListeners();
  }

  // ── Initialization & Persistence ──────────────────────────────────────────

  Future<void> initialize() async {
    await _load();
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load enabled state
      _enabled = prefs.getBool('search_history_enabled') ?? true;

      // Load history
      final raw = prefs.getStringList(_historyKey) ?? [];
      _history.clear();
      for (final s in raw) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          _history.add(SearchHistoryEntry.fromJson(map));
        } catch (e) {
          debugPrint('SearchHistoryProvider: skipping corrupt entry – $e');
        }
      }
    } catch (e) {
      debugPrint('SearchHistoryProvider: load error – $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _history.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_historyKey, encoded);
    } catch (e) {
      debugPrint('SearchHistoryProvider: save error – $e');
    }
  }
}

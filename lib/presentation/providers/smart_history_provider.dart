import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Smart History Provider untuk advanced history management
///
/// Features:
/// - History per creator
/// - Resume position untuk post dengan banyak media
/// - Clear history per creator
/// - Search dan filter history
class SmartHistoryProvider extends ChangeNotifier {
  static const String _historyKey = 'smart_history';
  static const String _settingsKey = 'history_settings';

  List<HistoryItem> _history = [];
  Map<String, CreatorHistory> _creatorHistory = {};
  bool _isLoading = false;
  String? _error;

  // Settings
  bool _enableHistory = true;
  int _maxHistoryItems = 1000;
  int _daysToKeep = 30;

  // Getters
  List<HistoryItem> get history => List.unmodifiable(_history);
  Map<String, CreatorHistory> get creatorHistory =>
      Map.unmodifiable(_creatorHistory);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get enableHistory => _enableHistory;
  int get maxHistoryItems => _maxHistoryItems;
  int get daysToKeep => _daysToKeep;

  /// Initialize history
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadHistory();
      await _loadSettings();
      await _cleanupOldHistory();
    } catch (e) {
      _setError('Failed to initialize history: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load history from storage
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);

      if (historyJson != null) {
        final Map<String, dynamic> data = json.decode(historyJson);

        // Load main history
        if (data['history'] != null) {
          final List<dynamic> historyList = data['history'];
          _history = historyList
              .map((json) => HistoryItem.fromJson(json))
              .toList();
        }

        // Load creator history
        if (data['creatorHistory'] != null) {
          final Map<String, dynamic> creatorData = data['creatorHistory'];
          _creatorHistory = creatorData.map((key, value) {
            return MapEntry(key, CreatorHistory.fromJson(value));
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final settings = json.decode(settingsJson);
        _enableHistory = settings['enableHistory'] ?? true;
        _maxHistoryItems = settings['maxHistoryItems'] ?? 1000;
        _daysToKeep = settings['daysToKeep'] ?? 30;
      }
    } catch (e) {
      debugPrint('Error loading history settings: $e');
    }
  }

  /// Save history to storage
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'history': _history.map((item) => item.toJson()).toList(),
        'creatorHistory': _creatorHistory.map((key, value) {
          return MapEntry(key, value.toJson());
        }),
      };
      await prefs.setString(_historyKey, json.encode(data));
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'enableHistory': _enableHistory,
        'maxHistoryItems': _maxHistoryItems,
        'daysToKeep': _daysToKeep,
      };
      await prefs.setString(_settingsKey, json.encode(settings));
    } catch (e) {
      debugPrint('Error saving history settings: $e');
    }
  }

  /// Add history item
  Future<void> addToHistory({
    required String type,
    required String itemId,
    required String title,
    String? creatorId,
    String? creatorName,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_enableHistory) return;

    try {
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        itemId: itemId,
        title: title,
        creatorId: creatorId,
        creatorName: creatorName,
        thumbnailUrl: thumbnailUrl,
        metadata: metadata,
        timestamp: DateTime.now(),
      );

      // Remove existing item with same itemId
      _history.removeWhere((item) => item.itemId == itemId);

      // Add new item at the beginning
      _history.insert(0, historyItem);

      // Limit history size
      if (_history.length > _maxHistoryItems) {
        _history = _history.take(_maxHistoryItems).toList();
      }

      // Update creator history
      if (creatorId != null) {
        _updateCreatorHistory(creatorId, creatorName ?? 'Unknown', historyItem);
      }

      await _saveHistory();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  /// Update creator history
  void _updateCreatorHistory(
    String creatorId,
    String creatorName,
    HistoryItem item,
  ) {
    final existing = _creatorHistory[creatorId];

    if (existing != null) {
      // Update existing creator history
      existing.update(item);
    } else {
      // Create new creator history
      _creatorHistory[creatorId] = CreatorHistory(
        creatorId: creatorId,
        creatorName: creatorName,
        lastVisited: DateTime.now(),
        visitCount: 1,
        lastItem: item,
        items: [item],
      );
    }
  }

  /// Update resume position for post
  Future<void> updateResumePosition({
    required String postId,
    required int mediaIndex,
    String? creatorId,
    String? creatorName,
  }) async {
    if (!_enableHistory) return;

    try {
      // Update or create resume position
      final historyIndex = _history.indexWhere(
        (item) => item.type == 'post' && item.itemId == postId,
      );

      if (historyIndex != -1) {
        final item = _history[historyIndex];
        final updatedMetadata = Map<String, dynamic>.from(item.metadata ?? {});
        updatedMetadata['resumeMediaIndex'] = mediaIndex;
        updatedMetadata['lastUpdated'] = DateTime.now().toIso8601String();

        _history[historyIndex] = item.copyWith(
          timestamp: DateTime.now(),
          metadata: updatedMetadata,
        );
      } else {
        // Create new history item with resume position
        await addToHistory(
          type: 'post',
          itemId: postId,
          title: 'Post $postId',
          creatorId: creatorId,
          creatorName: creatorName,
          metadata: {
            'resumeMediaIndex': mediaIndex,
            'lastUpdated': DateTime.now().toIso8601String(),
          },
        );
      }

      await _saveHistory();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating resume position: $e');
    }
  }

  /// Get resume position for post
  int? getResumePosition(String postId) {
    try {
      final item = _history.firstWhere(
        (item) => item.type == 'post' && item.itemId == postId,
      );

      return item.metadata?['resumeMediaIndex'] as int?;
    } catch (e) {
      return null;
    }
  }

  /// Get history by type
  List<HistoryItem> getHistoryByType(String type) {
    return _history.where((item) => item.type == type).toList();
  }

  /// Get history by creator
  List<HistoryItem> getHistoryByCreator(String creatorId) {
    return _history.where((item) => item.creatorId == creatorId).toList();
  }

  /// Get recent history (last N items)
  List<HistoryItem> getRecentHistory(int count) {
    return _history.take(count).toList();
  }

  /// Search history
  List<HistoryItem> searchHistory(String query) {
    if (query.isEmpty) return _history;

    final lowerQuery = query.toLowerCase();
    return _history.where((item) {
      return item.title.toLowerCase().contains(lowerQuery) ||
          (item.creatorName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Remove history item
  Future<bool> removeFromHistory(String historyItemId) async {
    try {
      _history.removeWhere((item) => item.id == historyItemId);
      await _saveHistory();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to remove from history: $e');
      return false;
    }
  }

  /// Clear history for creator
  Future<bool> clearCreatorHistory(String creatorId) async {
    try {
      _history.removeWhere((item) => item.creatorId == creatorId);
      _creatorHistory.remove(creatorId);
      await _saveHistory();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to clear creator history: $e');
      return false;
    }
  }

  /// Clear all history
  Future<bool> clearAllHistory() async {
    try {
      _history.clear();
      _creatorHistory.clear();
      await _saveHistory();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to clear all history: $e');
      return false;
    }
  }

  /// Clean up old history
  Future<void> _cleanupOldHistory() async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _daysToKeep));

      _history.removeWhere((item) => item.timestamp.isBefore(cutoffDate));

      // Clean up creator history
      _creatorHistory.removeWhere((key, creatorHistory) {
        return creatorHistory.lastVisited.isBefore(cutoffDate);
      });

      await _saveHistory();
    } catch (e) {
      debugPrint('Error cleaning up old history: $e');
    }
  }

  /// Update settings
  Future<void> updateSettings({
    bool? enableHistory,
    int? maxHistoryItems,
    int? daysToKeep,
  }) async {
    if (enableHistory != null) _enableHistory = enableHistory;
    if (maxHistoryItems != null) _maxHistoryItems = maxHistoryItems;
    if (daysToKeep != null) _daysToKeep = daysToKeep;

    await _saveSettings();
    notifyListeners();
  }

  /// Get statistics
  Map<String, int> getStatistics() {
    return {
      'total': _history.length,
      'creators': _creatorHistory.length,
      'posts': getHistoryByType('post').length,
      'creators_viewed': getHistoryByType('creator').length,
      'media': getHistoryByType('media').length,
    };
  }

  /// Export history
  String exportHistory() {
    final exportData = {
      'history': _history.map((h) => h.toJson()).toList(),
      'creatorHistory': _creatorHistory.map((key, value) {
        return MapEntry(key, value.toJson());
      }),
      'settings': {
        'enableHistory': _enableHistory,
        'maxHistoryItems': _maxHistoryItems,
        'daysToKeep': _daysToKeep,
      },
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    };

    return json.encode(exportData);
  }

  /// Import history
  Future<bool> importHistory(String jsonData) async {
    try {
      final importData = json.decode(jsonData);

      // Import history
      if (importData['history'] != null) {
        final historyList = importData['history'] as List;
        final newHistory = historyList
            .map((json) => HistoryItem.fromJson(json))
            .toList();

        // Merge with existing (avoid duplicates by itemId)
        for (var newHistoryItem in newHistory) {
          if (!_history.any((h) => h.itemId == newHistoryItem.itemId)) {
            _history.add(newHistoryItem);
          }
        }
      }

      // Import creator history
      if (importData['creatorHistory'] != null) {
        final Map<String, dynamic> creatorData = importData['creatorHistory'];
        creatorData.forEach((key, value) {
          final creatorHistory = CreatorHistory.fromJson(value);
          if (!_creatorHistory.containsKey(key)) {
            _creatorHistory[key] = creatorHistory;
          }
        });
      }

      // Import settings
      if (importData['settings'] != null) {
        final settings = importData['settings'];
        _enableHistory = settings['enableHistory'] ?? _enableHistory;
        _maxHistoryItems = settings['maxHistoryItems'] ?? _maxHistoryItems;
        _daysToKeep = settings['daysToKeep'] ?? _daysToKeep;
      }

      await _saveHistory();
      await _saveSettings();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to import history: $e');
      return false;
    }
  }

  /// Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// History item model
class HistoryItem {
  final String id;
  final String type; // 'post', 'creator', 'media'
  final String itemId;
  final String title;
  final String? creatorId;
  final String? creatorName;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  const HistoryItem({
    required this.id,
    required this.type,
    required this.itemId,
    required this.title,
    this.creatorId,
    this.creatorName,
    this.thumbnailUrl,
    this.metadata,
    required this.timestamp,
  });

  HistoryItem copyWith({
    String? id,
    String? type,
    String? itemId,
    String? title,
    String? creatorId,
    String? creatorName,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'itemId': itemId,
      'title': title,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      type: json['type'],
      itemId: json['itemId'],
      title: json['title'],
      creatorId: json['creatorId'],
      creatorName: json['creatorName'],
      thumbnailUrl: json['thumbnailUrl'],
      metadata: json['metadata'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Creator history model
class CreatorHistory {
  final String creatorId;
  final String creatorName;
  DateTime lastVisited;
  int visitCount;
  HistoryItem lastItem;
  List<HistoryItem> items;

  CreatorHistory({
    required this.creatorId,
    required this.creatorName,
    required this.lastVisited,
    required this.visitCount,
    required this.lastItem,
    required this.items,
  });

  void update(HistoryItem item) {
    lastVisited = DateTime.now();
    visitCount++;
    lastItem = item;

    // Add to items if not exists
    if (!items.any((i) => i.id == item.id)) {
      items.insert(0, item);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'lastVisited': lastVisited.toIso8601String(),
      'visitCount': visitCount,
      'lastItem': lastItem.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory CreatorHistory.fromJson(Map<String, dynamic> json) {
    return CreatorHistory(
      creatorId: json['creatorId'],
      creatorName: json['creatorName'],
      lastVisited: DateTime.parse(json['lastVisited']),
      visitCount: json['visitCount'],
      lastItem: HistoryItem.fromJson(json['lastItem']),
      items: (json['items'] as List)
          .map((item) => HistoryItem.fromJson(item))
          .toList(),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Scroll Memory Provider untuk mengingat posisi scroll
///
/// Features:
/// - Ingat posisi scroll per screen
/// - Ingat posisi media di post detail
/// - Auto restore saat kembali ke screen
/// - Memory management otomatis
class ScrollMemoryProvider extends ChangeNotifier {
  static const String _scrollMemoryKey = 'scroll_memory';
  static const String _settingsKey = 'scroll_memory_settings';

  Map<String, ScrollPosition> _scrollPositions = {};
  Map<String, MediaPosition> _mediaPositions = {};
  bool _isLoading = false;
  String? _error;

  // Settings
  bool _enableScrollMemory = true;
  int _maxMemoryItems = 100;
  int _daysToKeep = 7;

  // Getters
  Map<String, ScrollPosition> get scrollPositions =>
      Map.unmodifiable(_scrollPositions);
  Map<String, MediaPosition> get mediaPositions =>
      Map.unmodifiable(_mediaPositions);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get enableScrollMemory => _enableScrollMemory;
  int get maxMemoryItems => _maxMemoryItems;
  int get daysToKeep => _daysToKeep;

  /// Initialize scroll memory
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadScrollMemory();
      await _loadSettings();
      await _cleanupOldMemory();
    } catch (e) {
      _setError('Failed to initialize scroll memory: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load scroll memory from storage
  Future<void> _loadScrollMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryJson = prefs.getString(_scrollMemoryKey);

      if (memoryJson != null) {
        final Map<String, dynamic> data = json.decode(memoryJson);

        // Load scroll positions
        if (data['scrollPositions'] != null) {
          final Map<String, dynamic> scrollData = data['scrollPositions'];
          _scrollPositions = scrollData.map((key, value) {
            return MapEntry(key, ScrollPosition.fromJson(value));
          });
        }

        // Load media positions
        if (data['mediaPositions'] != null) {
          final Map<String, dynamic> mediaData = data['mediaPositions'];
          _mediaPositions = mediaData.map((key, value) {
            return MapEntry(key, MediaPosition.fromJson(value));
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading scroll memory: $e');
    }
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final settings = json.decode(settingsJson);
        _enableScrollMemory = settings['enableScrollMemory'] ?? true;
        _maxMemoryItems = settings['maxMemoryItems'] ?? 100;
        _daysToKeep = settings['daysToKeep'] ?? 7;
      }
    } catch (e) {
      debugPrint('Error loading scroll memory settings: $e');
    }
  }

  /// Save scroll memory to storage
  Future<void> _saveScrollMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'scrollPositions': _scrollPositions.map((key, value) {
          return MapEntry(key, value.toJson());
        }),
        'mediaPositions': _mediaPositions.map((key, value) {
          return MapEntry(key, value.toJson());
        }),
      };
      await prefs.setString(_scrollMemoryKey, json.encode(data));
    } catch (e) {
      debugPrint('Error saving scroll memory: $e');
    }
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'enableScrollMemory': _enableScrollMemory,
        'maxMemoryItems': _maxMemoryItems,
        'daysToKeep': _daysToKeep,
      };
      await prefs.setString(_settingsKey, json.encode(settings));
    } catch (e) {
      debugPrint('Error saving scroll memory settings: $e');
    }
  }

  /// Save scroll position
  Future<void> saveScrollPosition({
    required String screenKey,
    required double offset,
    double? maxScrollExtent,
    String? creatorId,
    String? postId,
  }) async {
    if (!_enableScrollMemory) return;

    try {
      final position = ScrollPosition(
        screenKey: screenKey,
        offset: offset,
        maxScrollExtent: maxScrollExtent,
        timestamp: DateTime.now(),
        creatorId: creatorId,
        postId: postId,
      );

      _scrollPositions[screenKey] = position;

      // Limit memory size
      if (_scrollPositions.length > _maxMemoryItems) {
        _removeOldestScrollPositions();
      }

      await _saveScrollMemory();
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving scroll position: $e');
    }
  }

  /// Get scroll position
  ScrollPosition? getScrollPosition(String screenKey) {
    return _scrollPositions[screenKey];
  }

  /// Save media position untuk post detail
  Future<void> saveMediaPosition({
    required String postId,
    required int mediaIndex,
    String? creatorId,
    double? scrollOffset,
  }) async {
    if (!_enableScrollMemory) return;

    try {
      final position = MediaPosition(
        postId: postId,
        mediaIndex: mediaIndex,
        timestamp: DateTime.now(),
        creatorId: creatorId,
        scrollOffset: scrollOffset,
      );

      _mediaPositions[postId] = position;

      // Limit memory size
      if (_mediaPositions.length > _maxMemoryItems) {
        _removeOldestMediaPositions();
      }

      await _saveScrollMemory();
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving media position: $e');
    }
  }

  /// Get media position untuk post detail
  MediaPosition? getMediaPosition(String postId) {
    return _mediaPositions[postId];
  }

  /// Update media index untuk post
  Future<void> updateMediaIndex({
    required String postId,
    required int newMediaIndex,
    String? creatorId,
  }) async {
    if (!_enableScrollMemory) return;

    try {
      final existing = _mediaPositions[postId];
      if (existing != null) {
        final updated = existing.copyWith(
          mediaIndex: newMediaIndex,
          timestamp: DateTime.now(),
        );
        _mediaPositions[postId] = updated;
      } else {
        await saveMediaPosition(
          postId: postId,
          mediaIndex: newMediaIndex,
          creatorId: creatorId,
        );
      }

      await _saveScrollMemory();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating media index: $e');
    }
  }

  /// Get scroll positions by creator
  List<ScrollPosition> getScrollPositionsByCreator(String creatorId) {
    return _scrollPositions.values
        .where((position) => position.creatorId == creatorId)
        .toList();
  }

  /// Get media positions by creator
  List<MediaPosition> getMediaPositionsByCreator(String creatorId) {
    return _mediaPositions.values
        .where((position) => position.creatorId == creatorId)
        .toList();
  }

  /// Clear scroll position untuk screen
  Future<bool> clearScrollPosition(String screenKey) async {
    try {
      _scrollPositions.remove(screenKey);
      await _saveScrollMemory();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to clear scroll position: $e');
      return false;
    }
  }

  /// Clear media position untuk post
  Future<bool> clearMediaPosition(String postId) async {
    try {
      _mediaPositions.remove(postId);
      await _saveScrollMemory();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to clear media position: $e');
      return false;
    }
  }

  /// Clear all positions untuk creator
  Future<bool> clearCreatorPositions(String creatorId) async {
    try {
      _scrollPositions.removeWhere(
        (key, position) => position.creatorId == creatorId,
      );
      _mediaPositions.removeWhere(
        (key, position) => position.creatorId == creatorId,
      );
      await _saveScrollMemory();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to clear creator positions: $e');
      return false;
    }
  }

  /// Clear all scroll memory
  Future<bool> clearAllMemory() async {
    try {
      _scrollPositions.clear();
      _mediaPositions.clear();
      await _saveScrollMemory();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to clear all memory: $e');
      return false;
    }
  }

  /// Remove oldest scroll positions
  void _removeOldestScrollPositions() {
    if (_scrollPositions.length <= _maxMemoryItems) return;

    final sortedPositions = _scrollPositions.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final toRemove = sortedPositions.take(
      _scrollPositions.length - _maxMemoryItems,
    );
    for (var position in toRemove) {
      _scrollPositions.remove(position.screenKey);
    }
  }

  /// Remove oldest media positions
  void _removeOldestMediaPositions() {
    if (_mediaPositions.length <= _maxMemoryItems) return;

    final sortedPositions = _mediaPositions.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final toRemove = sortedPositions.take(
      _mediaPositions.length - _maxMemoryItems,
    );
    for (var position in toRemove) {
      _mediaPositions.remove(position.postId);
    }
  }

  /// Clean up old memory
  Future<void> _cleanupOldMemory() async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _daysToKeep));

      _scrollPositions.removeWhere((key, position) {
        return position.timestamp.isBefore(cutoffDate);
      });

      _mediaPositions.removeWhere((key, position) {
        return position.timestamp.isBefore(cutoffDate);
      });

      await _saveScrollMemory();
    } catch (e) {
      debugPrint('Error cleaning up old memory: $e');
    }
  }

  /// Update settings
  Future<void> updateSettings({
    bool? enableScrollMemory,
    int? maxMemoryItems,
    int? daysToKeep,
  }) async {
    if (enableScrollMemory != null) _enableScrollMemory = enableScrollMemory;
    if (maxMemoryItems != null) _maxMemoryItems = maxMemoryItems;
    if (daysToKeep != null) _daysToKeep = daysToKeep;

    await _saveSettings();
    notifyListeners();
  }

  /// Get statistics
  Map<String, int> getStatistics() {
    return {
      'scrollPositions': _scrollPositions.length,
      'mediaPositions': _mediaPositions.length,
      'totalMemory': _scrollPositions.length + _mediaPositions.length,
    };
  }

  /// Export memory data
  String exportMemory() {
    final exportData = {
      'scrollPositions': _scrollPositions.map((key, value) {
        return MapEntry(key, value.toJson());
      }),
      'mediaPositions': _mediaPositions.map((key, value) {
        return MapEntry(key, value.toJson());
      }),
      'settings': {
        'enableScrollMemory': _enableScrollMemory,
        'maxMemoryItems': _maxMemoryItems,
        'daysToKeep': _daysToKeep,
      },
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    };

    return json.encode(exportData);
  }

  /// Import memory data
  Future<bool> importMemory(String jsonData) async {
    try {
      final importData = json.decode(jsonData);

      // Import scroll positions
      if (importData['scrollPositions'] != null) {
        final Map<String, dynamic> scrollData = importData['scrollPositions'];
        scrollData.forEach((key, value) {
          final position = ScrollPosition.fromJson(value);
          if (!_scrollPositions.containsKey(key)) {
            _scrollPositions[key] = position;
          }
        });
      }

      // Import media positions
      if (importData['mediaPositions'] != null) {
        final Map<String, dynamic> mediaData = importData['mediaPositions'];
        mediaData.forEach((key, value) {
          final position = MediaPosition.fromJson(value);
          if (!_mediaPositions.containsKey(key)) {
            _mediaPositions[key] = position;
          }
        });
      }

      // Import settings
      if (importData['settings'] != null) {
        final settings = importData['settings'];
        _enableScrollMemory =
            settings['enableScrollMemory'] ?? _enableScrollMemory;
        _maxMemoryItems = settings['maxMemoryItems'] ?? _maxMemoryItems;
        _daysToKeep = settings['daysToKeep'] ?? _daysToKeep;
      }

      await _saveScrollMemory();
      await _saveSettings();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to import memory: $e');
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

/// Scroll position model
class ScrollPosition {
  final String screenKey;
  final double offset;
  final double? maxScrollExtent;
  final DateTime timestamp;
  final String? creatorId;
  final String? postId;

  const ScrollPosition({
    required this.screenKey,
    required this.offset,
    this.maxScrollExtent,
    required this.timestamp,
    this.creatorId,
    this.postId,
  });

  ScrollPosition copyWith({
    String? screenKey,
    double? offset,
    double? maxScrollExtent,
    DateTime? timestamp,
    String? creatorId,
    String? postId,
  }) {
    return ScrollPosition(
      screenKey: screenKey ?? this.screenKey,
      offset: offset ?? this.offset,
      maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
      timestamp: timestamp ?? this.timestamp,
      creatorId: creatorId ?? this.creatorId,
      postId: postId ?? this.postId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'screenKey': screenKey,
      'offset': offset,
      'maxScrollExtent': maxScrollExtent,
      'timestamp': timestamp.toIso8601String(),
      'creatorId': creatorId,
      'postId': postId,
    };
  }

  factory ScrollPosition.fromJson(Map<String, dynamic> json) {
    return ScrollPosition(
      screenKey: json['screenKey'],
      offset: json['offset'].toDouble(),
      maxScrollExtent: json['maxScrollExtent']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      creatorId: json['creatorId'],
      postId: json['postId'],
    );
  }
}

/// Media position model
class MediaPosition {
  final String postId;
  final int mediaIndex;
  final DateTime timestamp;
  final String? creatorId;
  final double? scrollOffset;

  const MediaPosition({
    required this.postId,
    required this.mediaIndex,
    required this.timestamp,
    this.creatorId,
    this.scrollOffset,
  });

  MediaPosition copyWith({
    String? postId,
    int? mediaIndex,
    DateTime? timestamp,
    String? creatorId,
    double? scrollOffset,
  }) {
    return MediaPosition(
      postId: postId ?? this.postId,
      mediaIndex: mediaIndex ?? this.mediaIndex,
      timestamp: timestamp ?? this.timestamp,
      creatorId: creatorId ?? this.creatorId,
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'mediaIndex': mediaIndex,
      'timestamp': timestamp.toIso8601String(),
      'creatorId': creatorId,
      'scrollOffset': scrollOffset,
    };
  }

  factory MediaPosition.fromJson(Map<String, dynamic> json) {
    return MediaPosition(
      postId: json['postId'],
      mediaIndex: json['mediaIndex'],
      timestamp: DateTime.parse(json['timestamp']),
      creatorId: json['creatorId'],
      scrollOffset: json['scrollOffset']?.toDouble(),
    );
  }
}

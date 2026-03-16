import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Data Usage Categories
enum UsageCategory { images, videos, thumbnails, apiCalls, attachments, other }

/// Usage Data Model
class UsageData {
  final DateTime date;
  final Map<UsageCategory, int> categoryUsage;
  final int totalUsage;
  final int sessionCount;

  UsageData({
    required this.date,
    required this.categoryUsage,
    required this.totalUsage,
    this.sessionCount = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'categoryUsage': categoryUsage.map((k, v) => MapEntry(k.name, v)),
      'totalUsage': totalUsage,
      'sessionCount': sessionCount,
    };
  }

  factory UsageData.fromJson(Map<String, dynamic> json) {
    return UsageData(
      date: DateTime.parse(json['date']),
      categoryUsage: Map.from(json['categoryUsage']).map(
        (k, v) => MapEntry(
          UsageCategory.values.firstWhere((e) => e.name == k),
          v as int,
        ),
      ),
      totalUsage: json['totalUsage'],
      sessionCount: json['sessionCount'] ?? 1,
    );
  }
}

/// Usage Limits Configuration
class UsageLimits {
  final int dailyLimitMB;
  final int weeklyLimitMB;
  final int monthlyLimitMB;
  final bool enableWarnings;
  final bool autoDataSaver;
  final int warningThreshold;
  final int criticalThreshold;

  const UsageLimits({
    this.dailyLimitMB = 100,
    this.weeklyLimitMB = 500,
    this.monthlyLimitMB = 2000,
    this.enableWarnings = true,
    this.autoDataSaver = false,
    this.warningThreshold = 80,
    this.criticalThreshold = 95,
  });

  Map<String, dynamic> toJson() {
    return {
      'dailyLimitMB': dailyLimitMB,
      'weeklyLimitMB': weeklyLimitMB,
      'monthlyLimitMB': monthlyLimitMB,
      'enableWarnings': enableWarnings,
      'autoDataSaver': autoDataSaver,
      'warningThreshold': warningThreshold,
      'criticalThreshold': criticalThreshold,
    };
  }

  factory UsageLimits.fromJson(Map<String, dynamic> json) {
    return UsageLimits(
      dailyLimitMB: json['dailyLimitMB'] ?? 100,
      weeklyLimitMB: json['weeklyLimitMB'] ?? 500,
      monthlyLimitMB: json['monthlyLimitMB'] ?? 2000,
      enableWarnings: json['enableWarnings'] ?? true,
      autoDataSaver: json['autoDataSaver'] ?? false,
      warningThreshold: json['warningThreshold'] ?? 80,
      criticalThreshold: json['criticalThreshold'] ?? 95,
    );
  }
}

/// Main Data Usage Tracker
class DataUsageTracker extends ChangeNotifier {
  static const String _storageKey = 'data_usage_tracker';
  static const String _limitsKey = 'usage_limits';
  static const String _historyKey = 'usage_history';

  // Current session data
  int _sessionUsage = 0;
  final Map<UsageCategory, int> _sessionCategoryUsage = {};
  DateTime _sessionStart = DateTime.now();

  // Historical data
  UsageData? _todayUsage;
  UsageData? _weeklyUsage;
  UsageData? _monthlyUsage;
  List<UsageData> _usageHistory = [];

  // Configuration
  UsageLimits _limits = const UsageLimits();

  // Getters
  int get sessionUsage => _sessionUsage;
  Map<UsageCategory, int> get sessionCategoryUsage =>
      Map.unmodifiable(_sessionCategoryUsage);
  DateTime get sessionStart => _sessionStart;
  UsageData? get todayUsage => _todayUsage;
  UsageData? get weeklyUsage => _weeklyUsage;
  UsageData? get monthlyUsage => _monthlyUsage;
  List<UsageData> get usageHistory => List.unmodifiable(_usageHistory);
  UsageLimits get limits => _limits;

  DataUsageTracker() {
    _initializeCategoryUsage();
    _loadStoredData();
    _startSession();
  }

  void _initializeCategoryUsage() {
    for (final category in UsageCategory.values) {
      _sessionCategoryUsage[category] = 0;
    }
  }

  void _startSession() {
    _sessionStart = DateTime.now();
    _sessionUsage = 0;
    _sessionCategoryUsage.clear();
    _initializeCategoryUsage();
    notifyListeners();
  }

  /// Track data usage for a specific category
  void trackUsage(int bytes, {UsageCategory category = UsageCategory.other}) {
    _sessionUsage += bytes;
    _sessionCategoryUsage[category] =
        (_sessionCategoryUsage[category] ?? 0) + bytes;

    // Update today's usage
    _updateTodayUsage(bytes, category);

    // Check limits and show warnings
    if (_limits.enableWarnings) {
      _checkUsageLimits();
    }

    // Save periodically
    if (_sessionUsage % 1024 == 0) {
      // Save every 1KB
      _saveToStorage();
    }

    notifyListeners();
  }

  /// Track image usage specifically
  void trackImageUsage(int bytes) {
    trackUsage(bytes, category: UsageCategory.images);
  }

  /// Track video usage specifically
  void trackVideoUsage(int bytes) {
    trackUsage(bytes, category: UsageCategory.videos);
  }

  /// Track API call usage
  void trackApiUsage(int bytes) {
    trackUsage(bytes, category: UsageCategory.apiCalls);
  }

  /// Track thumbnail usage
  void trackThumbnailUsage(int bytes) {
    trackUsage(bytes, category: UsageCategory.thumbnails);
  }

  void _updateTodayUsage(int bytes, UsageCategory category) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    if (_todayUsage == null || _todayUsage!.date != todayKey) {
      _todayUsage = UsageData(
        date: todayKey,
        categoryUsage: Map.from(
          UsageCategory.values.asMap().map((k, v) => MapEntry(v, 0)),
        ),
        totalUsage: 0,
      );
    }

    final updatedCategoryUsage = Map<UsageCategory, int>.from(
      _todayUsage!.categoryUsage,
    );
    updatedCategoryUsage[category] =
        (updatedCategoryUsage[category] ?? 0) + bytes;

    _todayUsage = UsageData(
      date: todayKey,
      categoryUsage: updatedCategoryUsage,
      totalUsage: _todayUsage!.totalUsage + bytes,
      sessionCount: _todayUsage!.sessionCount,
    );
  }

  void _checkUsageLimits() {
    if (_todayUsage == null) return;

    final dailyPercent =
        (_todayUsage!.totalUsage / (_limits.dailyLimitMB * 1024 * 1024)) * 100;

    if (dailyPercent >= _limits.criticalThreshold) {
      _showCriticalAlert(dailyPercent);
    } else if (dailyPercent >= _limits.warningThreshold) {
      _showWarningAlert(dailyPercent);
    }
  }

  void _showWarningAlert(double percentage) {
    debugPrint(
      '⚠️ DATA USAGE WARNING: ${percentage.toStringAsFixed(1)}% of daily limit used',
    );
    // TODO: Show in-app notification
  }

  void _showCriticalAlert(double percentage) {
    debugPrint(
      '🚨 CRITICAL DATA USAGE: ${percentage.toStringAsFixed(1)}% of daily limit used!',
    );
    // TODO: Show critical dialog with data saver option
  }

  /// Update usage limits
  void updateLimits(UsageLimits newLimits) {
    _limits = newLimits;
    _saveLimits();
    notifyListeners();
  }

  /// Reset current session
  void resetSession() {
    _startSession();
  }

  /// Get usage statistics
  Map<String, dynamic> getUsageStats() {
    return {
      'session': {
        'usage': _sessionUsage,
        'duration': DateTime.now().difference(_sessionStart).inMinutes,
        'categoryBreakdown': _sessionCategoryUsage,
      },
      'today': _todayUsage?.toJson(),
      'weekly': _weeklyUsage?.toJson(),
      'monthly': _monthlyUsage?.toJson(),
      'limits': _limits.toJson(),
    };
  }

  /// Get top data consuming category
  UsageCategory getTopDataConsumer() {
    return _sessionCategoryUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get usage in MB for display
  double getUsageInMB(int bytes) {
    return bytes / (1024 * 1024);
  }

  /// Save data to local storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save current session data
      await prefs.setString(
        _storageKey,
        json.encode({
          'sessionUsage': _sessionUsage,
          'sessionCategoryUsage': _sessionCategoryUsage.map(
            (k, v) => MapEntry(k.name, v),
          ),
          'sessionStart': _sessionStart.toIso8601String(),
        }),
      );

      // Save today's usage
      if (_todayUsage != null) {
        await prefs.setString(
          'today_usage',
          json.encode(_todayUsage!.toJson()),
        );
      }

      // Save usage history
      await prefs.setString(
        _historyKey,
        json.encode(_usageHistory.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving usage data: $e');
    }
  }

  /// Save limits
  Future<void> _saveLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_limitsKey, json.encode(_limits.toJson()));
    } catch (e) {
      debugPrint('Error saving limits: $e');
    }
  }

  /// Load stored data
  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load limits
      final limitsJson = prefs.getString(_limitsKey);
      if (limitsJson != null) {
        _limits = UsageLimits.fromJson(json.decode(limitsJson));
      }

      // Load today's usage
      final todayUsageJson = prefs.getString('today_usage');
      if (todayUsageJson != null) {
        _todayUsage = UsageData.fromJson(json.decode(todayUsageJson));
      }

      // Load usage history
      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        _usageHistory = historyList.map((e) => UsageData.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading usage data: $e');
    }
  }

  /// Clean old usage data (keep last 30 days)
  Future<void> cleanupOldData() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    _usageHistory.removeWhere((data) => data.date.isBefore(cutoffDate));
    await _saveToStorage();
  }

  /// Generate daily report
  Map<String, dynamic> generateDailyReport() {
    if (_todayUsage == null) return {};

    return {
      'date': _todayUsage!.date.toIso8601String(),
      'totalUsageMB': getUsageInMB(_todayUsage!.totalUsage),
      'categoryBreakdown': _todayUsage!.categoryUsage.map(
        (k, v) => MapEntry(k.name, getUsageInMB(v)),
      ),
      'sessionCount': _todayUsage!.sessionCount,
      'topCategory': getTopDataConsumer().name,
    };
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Severity level of a data usage alert.
enum DataUsageAlertLevel { warning, critical }

/// Holds information about a pending data usage alert to be shown by the UI.
class DataUsageAlert {
  final DataUsageAlertLevel level;
  final double percentage;

  const DataUsageAlert({required this.level, required this.percentage});
}

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
    final decodedMap = Map<String, dynamic>.from(
      (json['categoryUsage'] as Map?) ?? const {},
    );
    final categoryUsage = {
      for (final category in UsageCategory.values) category: 0,
      ...decodedMap.map(
        (k, v) => MapEntry(
          UsageCategory.values.firstWhere(
            (e) => e.name == k,
            orElse: () => UsageCategory.other,
          ),
          (v as num?)?.toInt() ?? 0,
        ),
      ),
    };

    return UsageData(
      date: DateTime.parse(json['date']),
      categoryUsage: categoryUsage,
      totalUsage: (json['totalUsage'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 1,
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

  UsageLimits copyWith({
    int? dailyLimitMB,
    int? weeklyLimitMB,
    int? monthlyLimitMB,
    bool? enableWarnings,
    bool? autoDataSaver,
    int? warningThreshold,
    int? criticalThreshold,
  }) {
    return UsageLimits(
      dailyLimitMB: dailyLimitMB ?? this.dailyLimitMB,
      weeklyLimitMB: weeklyLimitMB ?? this.weeklyLimitMB,
      monthlyLimitMB: monthlyLimitMB ?? this.monthlyLimitMB,
      enableWarnings: enableWarnings ?? this.enableWarnings,
      autoDataSaver: autoDataSaver ?? this.autoDataSaver,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
    );
  }
}

/// Main Data Usage Tracker
class DataUsageTracker extends ChangeNotifier {
  static const String _storageKey = 'data_usage_tracker';
  static const String _limitsKey = 'usage_limits';
  static const String _historyKey = 'usage_history';
  static const String _todayKey = 'today_usage';

  // Notify threshold keeps dashboard responsive without rebuilding on every
  // small chunk; persist threshold reduces storage I/O during heavy media loads.
  static const int _notifyByteThreshold = 32 * 1024;
  static const int _persistByteThreshold = 256 * 1024;
  static const Duration _notifyMinInterval = Duration(milliseconds: 500);
  static const Duration _persistMinInterval = Duration(seconds: 10);

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

  // Pending alert to be consumed by the UI layer
  DataUsageAlert? _pendingAlert;

  DateTime _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _bytesSinceLastNotify = 0;
  DateTime _lastPersistTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _bytesSinceLastPersist = 0;

  DateTime? _warningShownAtDay;
  DateTime? _criticalShownAtDay;

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

  /// The most recent unread data-usage alert.
  DataUsageAlert? get pendingAlert => _pendingAlert;

  DataUsageTracker() {
    _initializeCategoryUsage();
    _loadStoredData().then((_) {
      _normalizeLoadedState();
      _startSession();
    });
  }

  static DateTime dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static UsageCategory categorizeRequest(
    String url, {
    String? contentType,
    bool forceAttachment = false,
  }) {
    if (forceAttachment) return UsageCategory.attachments;

    final lowerUrl = url.toLowerCase();
    final lowerContentType = contentType?.toLowerCase() ?? '';

    final isApi =
        lowerUrl.contains('/api/') ||
        lowerUrl.contains('/v1/') ||
        lowerContentType.contains('application/json') ||
        lowerContentType.contains('text/json');
    if (isApi) return UsageCategory.apiCalls;

    final isThumb =
        lowerUrl.contains('thumb') ||
        lowerUrl.contains('thumbnail') ||
        lowerUrl.contains('preview') ||
        (lowerContentType.contains('image/') &&
            (lowerUrl.contains('/thumbnail/') ||
                lowerUrl.contains('/thumbnails/')));
    if (isThumb) return UsageCategory.thumbnails;

    final isVideo =
        lowerContentType.startsWith('video/') ||
        _matchesAny(lowerUrl, const [
          '.mp4',
          '.avi',
          '.mov',
          '.wmv',
          '.flv',
          '.webm',
          '.mkv',
          '.m4v',
        ]);
    if (isVideo) return UsageCategory.videos;

    final isImage =
        lowerContentType.startsWith('image/') ||
        _matchesAny(lowerUrl, const [
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp',
          '.bmp',
          '.svg',
          '.avif',
        ]);
    if (isImage) return UsageCategory.images;

    final isAttachment =
        lowerUrl.contains('/attachment') ||
        lowerUrl.contains('/file') ||
        lowerUrl.contains('/download') ||
        lowerContentType.contains('application/octet-stream');
    if (isAttachment) return UsageCategory.attachments;

    return UsageCategory.other;
  }

  static bool _matchesAny(String value, List<String> suffixes) {
    final q = value.indexOf('?');
    final base = q > 0 ? value.substring(0, q) : value;
    for (final suffix in suffixes) {
      if (base.endsWith(suffix)) return true;
    }
    return false;
  }

  /// Mark the current pending alert as handled.
  void clearPendingAlert() {
    if (_pendingAlert == null) return;
    _pendingAlert = null;
    notifyListeners();
  }

  void _initializeCategoryUsage() {
    for (final category in UsageCategory.values) {
      _sessionCategoryUsage[category] = 0;
    }
  }

  void _normalizeLoadedState() {
    _sessionCategoryUsage
      ..clear()
      ..addAll({for (final c in UsageCategory.values) c: 0});

    if (_todayUsage != null) {
      final merged = {
        for (final c in UsageCategory.values) c: 0,
        ..._todayUsage!.categoryUsage,
      };
      _todayUsage = UsageData(
        date: dayKey(_todayUsage!.date),
        categoryUsage: merged,
        totalUsage: _todayUsage!.totalUsage,
        sessionCount: _todayUsage!.sessionCount,
      );
    }

    _usageHistory = _usageHistory
        .map(
          (item) => UsageData(
            date: dayKey(item.date),
            categoryUsage: {
              for (final c in UsageCategory.values) c: 0,
              ...item.categoryUsage,
            },
            totalUsage: item.totalUsage,
            sessionCount: item.sessionCount,
          ),
        )
        .toList();

    _dedupeAndSortHistory();
    _rolloverTodayIfNeeded();
    _recalculateAggregates();
  }

  void _startSession() {
    _sessionStart = DateTime.now();
    _sessionUsage = 0;
    _sessionCategoryUsage
      ..clear()
      ..addAll({for (final category in UsageCategory.values) category: 0});

    _ensureTodayUsage(incrementSession: true);
    _recalculateAggregates();
    _notifyThrottled(force: true);
  }

  /// Track data usage for a specific category
  void trackUsage(int bytes, {UsageCategory category = UsageCategory.other}) {
    if (bytes <= 0) return;

    _rolloverTodayIfNeeded();

    _sessionUsage += bytes;
    _sessionCategoryUsage[category] =
        (_sessionCategoryUsage[category] ?? 0) + bytes;

    _updateTodayUsage(bytes, category);
    _recalculateAggregates();

    if (_limits.enableWarnings) {
      _checkUsageLimits();
    }

    _bytesSinceLastNotify += bytes;
    _bytesSinceLastPersist += bytes;

    _notifyThrottled();
    unawaited(_saveToStorage());
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

  void _ensureTodayUsage({bool incrementSession = false}) {
    final today = dayKey(DateTime.now());
    if (_todayUsage == null || _todayUsage!.date != today) {
      _todayUsage = UsageData(
        date: today,
        categoryUsage: {
          for (final category in UsageCategory.values) category: 0,
        },
        totalUsage: 0,
        sessionCount: incrementSession ? 1 : 0,
      );
      return;
    }

    if (incrementSession) {
      _todayUsage = UsageData(
        date: _todayUsage!.date,
        categoryUsage: Map<UsageCategory, int>.from(_todayUsage!.categoryUsage),
        totalUsage: _todayUsage!.totalUsage,
        sessionCount: _todayUsage!.sessionCount + 1,
      );
    }
  }

  void _rolloverTodayIfNeeded() {
    if (_todayUsage == null) {
      _ensureTodayUsage();
      return;
    }

    final today = dayKey(DateTime.now());
    if (_todayUsage!.date == today) return;

    if (_todayUsage!.totalUsage > 0 || _todayUsage!.sessionCount > 0) {
      _upsertHistory(_todayUsage!);
    }

    _todayUsage = UsageData(
      date: today,
      categoryUsage: {for (final category in UsageCategory.values) category: 0},
      totalUsage: 0,
      sessionCount: 0,
    );

    _warningShownAtDay = null;
    _criticalShownAtDay = null;
  }

  void _updateTodayUsage(int bytes, UsageCategory category) {
    _ensureTodayUsage();

    final updatedCategoryUsage = Map<UsageCategory, int>.from(
      _todayUsage!.categoryUsage,
    );
    updatedCategoryUsage[category] =
        (updatedCategoryUsage[category] ?? 0) + bytes;

    _todayUsage = UsageData(
      date: _todayUsage!.date,
      categoryUsage: updatedCategoryUsage,
      totalUsage: _todayUsage!.totalUsage + bytes,
      sessionCount: _todayUsage!.sessionCount,
    );
  }

  void _recalculateAggregates() {
    _rollupIntoHistoryFromToday();

    final nowDay = dayKey(DateTime.now());
    final weeklyCutoff = nowDay.subtract(const Duration(days: 6));
    final monthlyCutoff = nowDay.subtract(const Duration(days: 29));

    _weeklyUsage = _aggregateRange(from: weeklyCutoff, to: nowDay);
    _monthlyUsage = _aggregateRange(from: monthlyCutoff, to: nowDay);
  }

  void _rollupIntoHistoryFromToday() {
    if (_todayUsage == null) return;

    _usageHistory.removeWhere((d) => d.date == _todayUsage!.date);
    _usageHistory.add(_todayUsage!);
    _dedupeAndSortHistory();

    final cutoffDate = dayKey(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    _usageHistory.removeWhere((data) => data.date.isBefore(cutoffDate));
  }

  UsageData _aggregateRange({required DateTime from, required DateTime to}) {
    final totals = {for (final category in UsageCategory.values) category: 0};
    var totalUsage = 0;
    var sessionCount = 0;

    for (final day in _usageHistory) {
      if (day.date.isBefore(from) || day.date.isAfter(to)) continue;
      totalUsage += day.totalUsage;
      sessionCount += day.sessionCount;
      for (final entry in day.categoryUsage.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }

    return UsageData(
      date: to,
      categoryUsage: totals,
      totalUsage: totalUsage,
      sessionCount: sessionCount,
    );
  }

  void _upsertHistory(UsageData usage) {
    _usageHistory.removeWhere((d) => d.date == usage.date);
    _usageHistory.add(usage);
    _dedupeAndSortHistory();
  }

  void _dedupeAndSortHistory() {
    final map = <DateTime, UsageData>{};
    for (final item in _usageHistory) {
      map[dayKey(item.date)] = item;
    }
    _usageHistory = map.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _checkUsageLimits() {
    if (_todayUsage == null) return;

    final dailyLimitBytes = _limits.dailyLimitMB * 1024 * 1024;
    if (dailyLimitBytes <= 0) return;

    final dailyPercent = (_todayUsage!.totalUsage / dailyLimitBytes) * 100;
    final today = dayKey(DateTime.now());

    if (dailyPercent >= _limits.criticalThreshold) {
      if (_criticalShownAtDay != today) {
        _criticalShownAtDay = today;
        _showCriticalAlert(dailyPercent);
      }
      return;
    }

    if (dailyPercent >= _limits.warningThreshold) {
      if (_warningShownAtDay != today) {
        _warningShownAtDay = today;
        _showWarningAlert(dailyPercent);
      }
    }
  }

  void _showWarningAlert(double percentage) {
    _pendingAlert = DataUsageAlert(
      level: DataUsageAlertLevel.warning,
      percentage: percentage,
    );
    _notifyThrottled(force: true);
  }

  void _showCriticalAlert(double percentage) {
    _pendingAlert = DataUsageAlert(
      level: DataUsageAlertLevel.critical,
      percentage: percentage,
    );
    _notifyThrottled(force: true);
  }

  void _notifyThrottled({bool force = false}) {
    final now = DateTime.now();
    final shouldNotify =
        force ||
        _bytesSinceLastNotify >= _notifyByteThreshold ||
        now.difference(_lastNotifyTime) >= _notifyMinInterval;
    if (!shouldNotify) return;

    _bytesSinceLastNotify = 0;
    _lastNotifyTime = now;
    notifyListeners();
  }

  /// Update usage limits
  void updateLimits(UsageLimits newLimits) {
    _limits = newLimits;
    _checkUsageLimits();
    _notifyThrottled(force: true);
    unawaited(_saveLimits());
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
    if (_sessionCategoryUsage.isEmpty) return UsageCategory.other;
    return _sessionCategoryUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get usage in MB for display
  double getUsageInMB(int bytes) {
    return bytes / (1024 * 1024);
  }

  /// Save data to local storage
  Future<void> _saveToStorage({bool force = false}) async {
    final now = DateTime.now();
    final shouldPersist =
        force ||
        _bytesSinceLastPersist >= _persistByteThreshold ||
        now.difference(_lastPersistTime) >= _persistMinInterval;
    if (!shouldPersist) return;

    _bytesSinceLastPersist = 0;
    _lastPersistTime = now;

    try {
      final prefs = await SharedPreferences.getInstance();

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

      if (_todayUsage != null) {
        await prefs.setString(_todayKey, json.encode(_todayUsage!.toJson()));
      }

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

      final limitsJson = prefs.getString(_limitsKey);
      if (limitsJson != null) {
        _limits = UsageLimits.fromJson(json.decode(limitsJson));
      }

      final todayUsageJson = prefs.getString(_todayKey);
      if (todayUsageJson != null) {
        _todayUsage = UsageData.fromJson(json.decode(todayUsageJson));
      }

      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        _usageHistory = historyList
            .whereType<Map<String, dynamic>>()
            .map(UsageData.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading usage data: $e');
    }
  }

  /// Clean old usage data (keep last 30 days)
  Future<void> cleanupOldData() async {
    final cutoffDate = dayKey(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    _usageHistory.removeWhere((data) => data.date.isBefore(cutoffDate));
    _recalculateAggregates();
    _notifyThrottled(force: true);
    await _saveToStorage(force: true);
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

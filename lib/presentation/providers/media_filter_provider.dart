import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Media filter types
enum MediaFilterType { all, images, videos, audio, documents, other }

/// Media filter settings
class MediaFilterSettings {
  final MediaFilterType type;
  final Set<String> allowedExtensions;
  final Set<String> blockedExtensions;
  final int minSizeBytes;
  final int maxSizeBytes;
  final bool hideDuplicates;
  final bool hideLowQuality;
  final bool hideWatermarked;

  const MediaFilterSettings({
    this.type = MediaFilterType.all,
    this.allowedExtensions = const {},
    this.blockedExtensions = const {},
    this.minSizeBytes = 0,
    this.maxSizeBytes = 0, // 0 means no limit
    this.hideDuplicates = false,
    this.hideLowQuality = false,
    this.hideWatermarked = false,
  });

  MediaFilterSettings copyWith({
    MediaFilterType? type,
    Set<String>? allowedExtensions,
    Set<String>? blockedExtensions,
    int? minSizeBytes,
    int? maxSizeBytes,
    bool? hideDuplicates,
    bool? hideLowQuality,
    bool? hideWatermarked,
  }) {
    return MediaFilterSettings(
      type: type ?? this.type,
      allowedExtensions: allowedExtensions ?? this.allowedExtensions,
      blockedExtensions: blockedExtensions ?? this.blockedExtensions,
      minSizeBytes: minSizeBytes ?? this.minSizeBytes,
      maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
      hideDuplicates: hideDuplicates ?? this.hideDuplicates,
      hideLowQuality: hideLowQuality ?? this.hideLowQuality,
      hideWatermarked: hideWatermarked ?? this.hideWatermarked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'allowedExtensions': allowedExtensions.toList(),
      'blockedExtensions': blockedExtensions.toList(),
      'minSizeBytes': minSizeBytes,
      'maxSizeBytes': maxSizeBytes,
      'hideDuplicates': hideDuplicates,
      'hideLowQuality': hideLowQuality,
      'hideWatermarked': hideWatermarked,
    };
  }

  factory MediaFilterSettings.fromJson(Map<String, dynamic> json) {
    return MediaFilterSettings(
      type: MediaFilterType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => MediaFilterType.all,
      ),
      allowedExtensions: Set<String>.from(json['allowedExtensions'] ?? []),
      blockedExtensions: Set<String>.from(json['blockedExtensions'] ?? []),
      minSizeBytes: json['minSizeBytes'] ?? 0,
      maxSizeBytes: json['maxSizeBytes'] ?? 0,
      hideDuplicates: json['hideDuplicates'] ?? false,
      hideLowQuality: json['hideLowQuality'] ?? false,
      hideWatermarked: json['hideWatermarked'] ?? false,
    );
  }
}

/// Media Filter Provider - Advanced media filtering
class MediaFilterProvider with ChangeNotifier {
  MediaFilterSettings _settings = const MediaFilterSettings();
  bool _isInitialized = false;
  bool _isEnabled = true;

  MediaFilterSettings get settings => _settings;
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;

  /// Initialize provider and load settings from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('media_filter_settings');
      final isEnabled = prefs.getBool('media_filter_enabled') ?? true;

      if (settingsJson != null) {
        // Parse settings (simplified implementation)
        _settings = const MediaFilterSettings();
      }

      _isEnabled = isEnabled;
      _isInitialized = true;
      notifyListeners();

      debugPrint('MediaFilterProvider: Initialized successfully');
    } catch (e) {
      debugPrint('MediaFilterProvider: Failed to initialize - $e');
    }
  }

  /// Update filter type
  void setFilterType(MediaFilterType type) {
    _settings = _settings.copyWith(type: type);
    _saveSettings();
    notifyListeners();

    debugPrint('MediaFilterProvider: Filter type changed to $type');
  }

  /// Add allowed extension
  void addAllowedExtension(String extension) {
    final newExtensions = Set<String>.from(_settings.allowedExtensions);
    newExtensions.add(extension.toLowerCase());
    _settings = _settings.copyWith(allowedExtensions: newExtensions);
    _saveSettings();
    notifyListeners();
  }

  /// Remove allowed extension
  void removeAllowedExtension(String extension) {
    final newExtensions = Set<String>.from(_settings.allowedExtensions);
    newExtensions.remove(extension.toLowerCase());
    _settings = _settings.copyWith(allowedExtensions: newExtensions);
    _saveSettings();
    notifyListeners();
  }

  /// Add blocked extension
  void addBlockedExtension(String extension) {
    final newExtensions = Set<String>.from(_settings.blockedExtensions);
    newExtensions.add(extension.toLowerCase());
    _settings = _settings.copyWith(blockedExtensions: newExtensions);
    _saveSettings();
    notifyListeners();
  }

  /// Remove blocked extension
  void removeBlockedExtension(String extension) {
    final newExtensions = Set<String>.from(_settings.blockedExtensions);
    newExtensions.remove(extension.toLowerCase());
    _settings = _settings.copyWith(blockedExtensions: newExtensions);
    _saveSettings();
    notifyListeners();
  }

  /// Set size limits
  void setSizeLimits({int? minSize, int? maxSize}) {
    _settings = _settings.copyWith(
      minSizeBytes: minSize ?? _settings.minSizeBytes,
      maxSizeBytes: maxSize ?? _settings.maxSizeBytes,
    );
    _saveSettings();
    notifyListeners();
  }

  /// Toggle duplicate hiding
  void toggleHideDuplicates() {
    _settings = _settings.copyWith(hideDuplicates: !_settings.hideDuplicates);
    _saveSettings();
    notifyListeners();
  }

  /// Toggle low quality hiding
  void toggleHideLowQuality() {
    _settings = _settings.copyWith(hideLowQuality: !_settings.hideLowQuality);
    _saveSettings();
    notifyListeners();
  }

  /// Toggle watermarked hiding
  void toggleHideWatermarked() {
    _settings = _settings.copyWith(hideWatermarked: !_settings.hideWatermarked);
    _saveSettings();
    notifyListeners();
  }

  /// Enable/disable filtering
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _saveSettings();
    notifyListeners();

    debugPrint(
      'MediaFilterProvider: Filter ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Reset to default settings
  void resetToDefaults() {
    _settings = const MediaFilterSettings();
    _isEnabled = true;
    _saveSettings();
    notifyListeners();

    debugPrint('MediaFilterProvider: Reset to defaults');
  }

  /// Check if media file passes filter
  bool shouldShowMedia(String url, int? fileSize) {
    if (!_isEnabled) return true;

    // Check file extension
    final extension = _getFileExtension(url).toLowerCase();

    // If blocked extensions contain this extension, hide it
    if (_settings.blockedExtensions.contains(extension)) {
      return false;
    }

    // If allowed extensions is not empty and doesn't contain this extension, hide it
    if (_settings.allowedExtensions.isNotEmpty &&
        !_settings.allowedExtensions.contains(extension)) {
      return false;
    }

    // Check size limits
    if (fileSize != null) {
      if (_settings.minSizeBytes > 0 && fileSize < _settings.minSizeBytes) {
        return false;
      }
      if (_settings.maxSizeBytes > 0 && fileSize > _settings.maxSizeBytes) {
        return false;
      }
    }

    // Check filter type
    switch (_settings.type) {
      case MediaFilterType.images:
        return _isImageFile(extension);
      case MediaFilterType.videos:
        return _isVideoFile(extension);
      case MediaFilterType.audio:
        return _isAudioFile(extension);
      case MediaFilterType.documents:
        return _isDocumentFile(extension);
      case MediaFilterType.other:
        return !_isImageFile(extension) &&
            !_isVideoFile(extension) &&
            !_isAudioFile(extension) &&
            !_isDocumentFile(extension);
      case MediaFilterType.all:
        return true;
    }
  }

  /// Get file extension from URL
  String _getFileExtension(String url) {
    return url.split('.').last.split('?').first;
  }

  /// Check if file is image
  bool _isImageFile(String extension) {
    const imageExtensions = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'svg',
      'ico',
      'tiff',
    };
    return imageExtensions.contains(extension);
  }

  /// Check if file is video
  bool _isVideoFile(String extension) {
    const videoExtensions = {
      'mp4',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      'mkv',
      'm4v',
      '3gp',
    };
    return videoExtensions.contains(extension);
  }

  /// Check if file is audio
  bool _isAudioFile(String extension) {
    const audioExtensions = {
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'wma',
      'm4a',
      'opus',
    };
    return audioExtensions.contains(extension);
  }

  /// Check if file is document
  bool _isDocumentFile(String extension) {
    const documentExtensions = {
      'pdf',
      'doc',
      'docx',
      'txt',
      'rtf',
      'odt',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
    };
    return documentExtensions.contains(extension);
  }

  /// Get display name for filter type
  String getFilterTypeDisplayName(MediaFilterType type) {
    switch (type) {
      case MediaFilterType.all:
        return 'All Media';
      case MediaFilterType.images:
        return 'Images Only';
      case MediaFilterType.videos:
        return 'Videos Only';
      case MediaFilterType.audio:
        return 'Audio Only';
      case MediaFilterType.documents:
        return 'Documents Only';
      case MediaFilterType.other:
        return 'Other Files';
    }
  }

  /// Get all supported extensions for a type
  List<String> getSupportedExtensions(MediaFilterType type) {
    switch (type) {
      case MediaFilterType.images:
        return [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'bmp',
          'webp',
          'svg',
          'ico',
          'tiff',
        ];
      case MediaFilterType.videos:
        return ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv', 'm4v', '3gp'];
      case MediaFilterType.audio:
        return ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a', 'opus'];
      case MediaFilterType.documents:
        return [
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'odt',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
        ];
      case MediaFilterType.other:
      case MediaFilterType.all:
        return [];
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save settings (simplified implementation)
      await prefs.setBool('media_filter_enabled', _isEnabled);

      debugPrint('MediaFilterProvider: Settings saved');
    } catch (e) {
      debugPrint('MediaFilterProvider: Failed to save settings - $e');
    }
  }

  /// Get filter statistics
  Map<String, dynamic> getStatistics() {
    return {
      'isEnabled': _isEnabled,
      'filterType': _settings.type.toString(),
      'allowedExtensions': _settings.allowedExtensions.length,
      'blockedExtensions': _settings.blockedExtensions.length,
      'hasSizeLimits': _settings.minSizeBytes > 0 || _settings.maxSizeBytes > 0,
      'hideDuplicates': _settings.hideDuplicates,
      'hideLowQuality': _settings.hideLowQuality,
      'hideWatermarked': _settings.hideWatermarked,
    };
  }
}

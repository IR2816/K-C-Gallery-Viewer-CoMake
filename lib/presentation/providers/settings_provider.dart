import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../domain/entities/api_source.dart';
import '../../config/domain_config.dart';

class SettingsProvider with ChangeNotifier {
  final KemonoRepository repository;

  SettingsProvider({required this.repository});

  Map<String, dynamic> _settings = {};
  bool _isLoading = false;
  List<String> _searchHistory = [];

  Map<String, dynamic> get settings => _settings;
  bool get isLoading => _isLoading;
  List<String> get searchHistory => _searchHistory;

  String get themeMode => _settings['theme_mode'] ?? 'system';
  int get gridColumns => _getGridColumns();
  bool get autoPlayVideo => _settings['auto_play_video'] ?? false;
  String get defaultService => _settings['default_service'] ?? 'all';
  bool get nsfwFilter => _settings['nsfw_filter'] ?? false;
  bool get loadThumbnails => _settings['load_thumbnails'] ?? true;
  ApiSource get defaultApiSource => _settings['default_api_source'] == 'coomer'
      ? ApiSource.coomer
      : ApiSource.kemono;
  String get defaultApiSourceName =>
      _settings['default_api_source'] ?? 'kemono';
  String get cacheSize => _settings['cache_size'] ?? 'medium';
  String get imageQuality => _settings['image_quality'] ?? 'medium';
  String get latestPostCardStyle =>
      _settings['latest_post_card_style'] ?? 'rich';
  int get latestPostsColumns => _settings['latest_posts_columns'] ?? 2;

  // New Settings Properties
  bool get hideNsfw => _settings['hide_nsfw'] ?? false;
  bool get autoplayVideo => _settings['autoplay_video'] ?? false;
  BoxFit get imageFitMode {
    final fitMode = _settings['image_fit_mode'] ?? 'cover';
    switch (fitMode) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  // Get grid columns with user setting
  int _getGridColumns() {
    final savedColumns = _settings['grid_columns'] ?? 2;
    return savedColumns; // Return user setting directly
  }

  // Set grid columns
  Future<void> setGridColumns(int columns) async {
    await updateSetting('grid_columns', columns);
  }

  // New Settings Methods
  Future<void> setHideNsfw(bool value) async {
    await updateSetting('hide_nsfw', value);
  }

  Future<void> setAutoplayVideo(bool value) async {
    await updateSetting('autoplay_video', value);
  }

  Future<void> setImageFitMode(BoxFit fit) async {
    String fitMode = 'cover';
    switch (fit) {
      case BoxFit.contain:
        fitMode = 'contain';
        break;
      case BoxFit.fill:
        fitMode = 'fill';
        break;
      case BoxFit.cover:
      default:
        fitMode = 'cover';
        break;
    }
    await updateSetting('image_fit_mode', fitMode);
  }

  Future<void> setDefaultApiSource(ApiSource source) async {
    await updateSetting('default_api_source', source.name);
  }

  // Domain preferences
  String get kemonoDomain =>
      _settings['kemono_domain'] ?? DomainConfig.defaultKemonoDomain;
  String get coomerDomain =>
      _settings['coomer_domain'] ?? DomainConfig.defaultCoomerDomain;

  // Get cleaned domains (without protocol)
  String get cleanKemonoDomain => DomainConfig.cleanDomain(kemonoDomain);
  String get cleanCoomerDomain => DomainConfig.cleanDomain(coomerDomain);

  // Get API base URLs
  String get kemonoApiUrl => DomainConfig.getApiBaseUrl(cleanKemonoDomain);
  String get coomerApiUrl => DomainConfig.getApiBaseUrl(cleanCoomerDomain);

  // Get media base URLs
  String get kemonoMediaUrl => DomainConfig.getMediaBaseUrl(cleanKemonoDomain);
  String get coomerMediaUrl => DomainConfig.getMediaBaseUrl(cleanCoomerDomain);

  // Get thumbnail base URLs
  String get kemonoThumbnailUrl =>
      DomainConfig.getThumbnailBaseUrl(cleanKemonoDomain);
  String get coomerThumbnailUrl =>
      DomainConfig.getThumbnailBaseUrl(cleanCoomerDomain);

  // Get API domains for fallback
  List<String> get kemonoApiDomains =>
      DomainConfig.getApiDomains(cleanKemonoDomain);
  List<String> get coomerApiDomains =>
      DomainConfig.getApiDomains(cleanCoomerDomain);

  // Domain validation
  bool get isKemonoDomainValid => DomainConfig.isValidDomain(cleanKemonoDomain);
  bool get isCoomerDomainValid => DomainConfig.isValidDomain(cleanCoomerDomain);

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await repository.getSettings();
      // Backward compatibility for legacy keys
      if (_settings['autoplay_video'] == null &&
          _settings['auto_play_video'] != null) {
        _settings['autoplay_video'] = _settings['auto_play_video'];
      }
      if (_settings['hide_nsfw'] == null && _settings['nsfw_filter'] != null) {
        _settings['hide_nsfw'] = _settings['nsfw_filter'];
      }
      _settings['image_fit_mode'] ??= 'cover';
      _settings['load_thumbnails'] ??= true;
      _settings['latest_post_card_style'] ??= 'rich';
      _settings['latest_posts_columns'] ??= 2;
      await loadSearchHistory(); // Load search history after settings
    } catch (e) {
      _settings = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    _settings[key] = value;
    await repository.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> resetSettings() async {
    _settings = {
      'theme_mode': 'system',
      'grid_columns': 2,
      'auto_play_video': false,
      'default_service': 'all',
      'nsfw_filter': false,
      'load_thumbnails': true,
      'default_api_source': 'kemono',
      'kemono_domain': 'kemono.cr',
      'coomer_domain': 'coomer.st',
      'hide_nsfw': false,
      'autoplay_video': false,
      'image_fit_mode': 'cover',
      'latest_post_card_style': 'rich',
      'latest_posts_columns': 2,
    };
    await repository.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setKemonoDomain(String domain) async {
    // Clean and validate domain
    final cleanedDomain = DomainConfig.cleanDomain(domain);
    if (DomainConfig.isValidDomain(cleanedDomain)) {
      await updateSetting('kemono_domain', cleanedDomain);
    } else {
      throw Exception('Invalid domain format: $domain');
    }
  }

  Future<void> setCoomerDomain(String domain) async {
    // Clean and validate domain
    final cleanedDomain = DomainConfig.cleanDomain(domain);
    if (DomainConfig.isValidDomain(cleanedDomain)) {
      await updateSetting('coomer_domain', cleanedDomain);
    } else {
      throw Exception('Invalid domain format: $domain');
    }
  }

  Future<void> setApiSource(ApiSource apiSource) async {
    await updateSetting(
      'default_api_source',
      apiSource == ApiSource.coomer ? 'coomer' : 'kemono',
    );
  }

  Future<void> setThemeMode(String themeMode) async {
    await updateSetting('theme_mode', themeMode);
  }

  Future<void> setCacheSize(String size) async {
    await updateSetting('cache_size', size);
  }

  Future<void> setImageQuality(String quality) async {
    await updateSetting('image_quality', quality);
  }

  Future<void> setLoadThumbnails(bool value) async {
    await updateSetting('load_thumbnails', value);
  }

  Future<void> setLatestPostCardStyle(String style) async {
    await updateSetting('latest_post_card_style', style);
  }

  Future<void> setLatestPostsColumns(int columns) async {
    await updateSetting('latest_posts_columns', columns);
  }

  // Search History Management
  Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    // Remove if already exists (to move to top)
    _searchHistory.remove(query.trim());

    // Add to top
    _searchHistory.insert(0, query.trim());

    // Keep only last 20 searches
    if (_searchHistory.length > 20) {
      _searchHistory = _searchHistory.take(20).toList();
    }

    // Save to settings
    await updateSetting('search_history', _searchHistory);
  }

  Future<void> loadSearchHistory() async {
    final history = _settings['search_history'] as List<dynamic>?;
    if (history != null) {
      _searchHistory = history.cast<String>();
    }
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    await updateSetting('search_history', []);
  }

  Future<void> removeFromSearchHistory(String query) async {
    _searchHistory.remove(query);
    await updateSetting('search_history', _searchHistory);
  }
}

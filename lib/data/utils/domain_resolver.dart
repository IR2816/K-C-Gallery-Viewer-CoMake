import '../../config/domain_config.dart';
import '../../domain/entities/api_source.dart';
import '../../utils/logger.dart';

/// Resolves API domains based on a creator/post service.
class DomainResolver {
  static const Set<String> _coomerServices = {
    'onlyfans',
    'fansly',
    'candfans',
  };

  static const Set<String> _knownKemonoServices = {
    'patreon',
    'fanbox',
    'fantia',
    'gumroad',
    'subscribestar',
    'afdian',
    'boosty',
    'dlsite',
    'discord',
    'pixiv',
    'pixivfanbox',
    'kemono',
  };

  /// Map a service name to the appropriate API source.
  static ApiSource apiSourceForService(String service) {
    final normalized = service.trim().toLowerCase();
    if (_coomerServices.contains(normalized)) {
      return ApiSource.coomer;
    }

    if (normalized.isNotEmpty &&
        !_knownKemonoServices.contains(normalized) &&
        !_coomerServices.contains(normalized)) {
      AppLogger.warning(
        'DomainResolver: Unknown service "$service". Defaulting to kemono.cr',
      );
    }

    return ApiSource.kemono;
  }

  /// Get the primary base URL (with /api) for a given service.
  static String getBaseUrl(String service) {
    final domains = getApiDomains(service: service);
    if (domains.isNotEmpty) return domains.first;

    final source = apiSourceForService(service);
    return source == ApiSource.coomer
        ? 'https://coomer.st/api'
        : 'https://kemono.cr/api';
  }

  /// Get the list of API domains (with /api) for fallback.
  static List<String> getApiDomains({String? service, ApiSource? apiSourceHint}) {
    final source = service != null && service.trim().isNotEmpty
        ? apiSourceForService(service)
        : (apiSourceHint ?? ApiSource.kemono);

    return source == ApiSource.coomer
        ? DomainConfig.coomerApiDomains
        : DomainConfig.kemonoApiDomains;
  }
}

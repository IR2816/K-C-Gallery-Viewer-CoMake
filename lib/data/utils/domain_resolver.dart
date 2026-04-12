import '../../config/domain_config.dart';
import '../../domain/entities/api_source.dart';
import '../../utils/logger.dart';

/// Resolves API domains based on a creator/post service.
class DomainResolver {
  static const Set<String> _coomerServices = {'onlyfans', 'fansly', 'candfans'};

  /// In-memory domain lock cache.
  ///
  /// Once a service is locked to an [ApiSource] via [lockDomain], that
  /// mapping is preserved for the lifetime of the app so the domain never
  /// flips mid-session.
  static final Map<String, ApiSource> _domainLocks = {};

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

  /// Permanently lock [service] to [source].
  ///
  /// Call this whenever a creator or post is first resolved so subsequent
  /// lookups for the same service always return the same domain without
  /// re-computing it.
  static void lockDomain(String service, ApiSource source) {
    final key = service.trim().toLowerCase();
    _domainLocks[key] = source;
  }

  /// Returns the locked [ApiSource] for [service].
  ///
  /// If no lock exists for [service], falls back to [apiSourceForService].
  /// The result of [apiSourceForService] is then automatically stored so
  /// subsequent calls hit the cache.
  static ApiSource lockedApiSourceForService(String service) {
    final key = service.trim().toLowerCase();
    if (_domainLocks.containsKey(key)) {
      return _domainLocks[key]!;
    }
    final resolved = apiSourceForService(service);
    _domainLocks[key] = resolved;
    return resolved;
  }

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
  static List<String> getApiDomains({
    String? service,
    ApiSource? apiSourceHint,
  }) {
    final source = service != null && service.trim().isNotEmpty
        ? apiSourceForService(service)
        : (apiSourceHint ?? ApiSource.kemono);

    return source == ApiSource.coomer
        ? DomainConfig.coomerApiDomains
        : DomainConfig.kemonoApiDomains;
  }
}

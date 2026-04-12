/// Dynamic Domain Configuration
/// Allows users to easily change domains without hardcoding
class DomainConfig {
  // Default domains
  static const String defaultKemonoDomain = 'kemono.cr';
  static const String defaultCoomerDomain = 'coomer.st';

  // API subdomains
  static const String kemonoApiSubdomain = 'kemono.cr';
  static const String coomerApiSubdomain = 'coomer.st';

  // Media subdomains
  static const String kemonoMediaSubdomain = 'n4.kemono.cr';
  static const String coomerMediaSubdomain = 'n4.coomer.st';

  // Thumbnail subdomains
  static const String kemonoThumbnailSubdomain = 'img.kemono.cr';
  static const String coomerThumbnailSubdomain = 'img.coomer.st';

  // Alternative domains for fallback
  static const List<String> kemonoApiDomains = [
    'https://kemono.cr/api',
    // 'https://kemono.su/api', // Removed - DNS resolution fails
  ];

  static const List<String> coomerApiDomains = [
    'https://coomer.st/api',
    // 'https://coomer.su/api', // Removed - might have DNS issues
  ];

  // Get API base URL for given domain
  static String getApiBaseUrl(String domain) {
    return 'https://$domain/api';
  }

  // Get media base URL for given domain
  static String getMediaBaseUrl(String domain) {
    return 'https://n4.$domain';
  }

  // Get thumbnail base URL for given domain
  static String getThumbnailBaseUrl(String domain) {
    return 'https://img.$domain/thumbnail/data';
  }

  // Get all API domains for fallback
  static List<String> getApiDomains(String domain) {
    if (domain.contains('coomer')) {
      return coomerApiDomains;
    } else {
      return kemonoApiDomains;
    }
  }

  // Validate domain format
  static bool isValidDomain(String domain) {
    if (domain.isEmpty) return false;

    // Basic domain validation
    final domainRegex = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return domainRegex.hasMatch(domain);
  }

  // Clean domain (remove protocol, trailing slash)
  static String cleanDomain(String domain) {
    String cleaned = domain.trim();

    // Remove protocol
    if (cleaned.startsWith('http://')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('https://')) {
      cleaned = cleaned.substring(8);
    }

    // Remove trailing slash
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    return cleaned;
  }

  // Get domain suggestions for user
  static List<String> getDomainSuggestions() {
    return ['kemono.cr', 'coomer.st'];
  }

  // Get HTTP headers for CDN requests based on domain
  static Map<String, String> getCdnHeaders(String domain) {
    return {
      'Accept': 'image/*, video/*, */*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://$domain/',
      'Origin': 'https://$domain',
      'Accept-Encoding': 'gzip, deflate',
      'Accept-Language': 'en-US,en;q=0.9',
      'DNT': '1',
      'Connection': 'keep-alive',
    };
  }
}

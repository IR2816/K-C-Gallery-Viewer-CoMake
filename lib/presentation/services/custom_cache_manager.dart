import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'header_http_file_service.dart';

/// Custom CacheManager with headers for Kemono/Coomer media
/// Ensures all cached requests include proper headers
final customCacheManager = CacheManager(
  Config(
    'kemonoCoomerCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 200,
    fileService: HeaderHttpFileService({
      'Accept': 'text/css',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://kemono.cr/',
    }),
  ),
);

/// CacheManager specifically for Coomer media
final coomerCacheManager = CacheManager(
  Config(
    'coomerCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 200,
    fileService: HeaderHttpFileService({
      'Accept': 'text/css',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://coomer.st/',
    }),
  ),
);

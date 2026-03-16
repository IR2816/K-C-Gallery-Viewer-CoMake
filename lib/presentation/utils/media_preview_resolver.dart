import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/logger.dart';

/// MediaPreviewResolver - Centralized thumbnail & fallback logic
/// Dipakai di LatestPostsScreen, PostDetailScreen, dan Gallery
class MediaPreviewResolver {
  /// Get thumbnail URL from RAW path (not from full URL)
  /// Example kemono thumbnail: https://img.kemono.cr/thumbnail/data/a4/41/a441621b83f7bf93d7ff1972fb7848233ac5e253c93365e451c0f00022d502a0.jpg
  /// Example coomer thumbnail: https://img.coomer.st/thumbnail/data/56/0b/560b7d65dc462caebf9a1530d95bd47374a0fdf2e40a585c83f3046b4ab1ba1e.jpg
  static String getThumbnailUrlFromPath(String rawPath, String apiSource) {
    if (rawPath.isEmpty) {
      AppLogger.debug('🔍 DEBUG: Empty raw path for thumbnail');
      return '';
    }

    // HAPUS query string (?f=...) dan fragment
    final cleanPath = rawPath.split('?').first.split('#').first;

    // PASTIKAN dimulai dengan /data/
    final dataIndex = cleanPath.indexOf('/data/');
    if (dataIndex == -1) {
      AppLogger.debug('🔍 DEBUG: No /data/ found in clean path: $cleanPath');
      return '';
    }

    // Ambil bagian setelah '/data/' untuk thumbnail path
    final dataPath = cleanPath.substring(dataIndex + 1);

    // Bangun URL thumbnail berdasarkan apiSource
    String thumbnailUrl;
    if (apiSource == 'coomer') {
      thumbnailUrl = 'https://img.coomer.st/thumbnail/$dataPath';
    } else {
      thumbnailUrl = 'https://img.kemono.cr/thumbnail/$dataPath';
    }

    AppLogger.debug('🔍 DEBUG: Raw Path: $rawPath');
    AppLogger.debug('🔍 DEBUG: Clean Path: $cleanPath');
    AppLogger.debug('🔍 DEBUG: Data Path: $dataPath');
    AppLogger.debug('🔍 DEBUG: API Source: $apiSource');
    AppLogger.debug('🔍 DEBUG: Thumbnail URL: $thumbnailUrl');

    return thumbnailUrl;
  }

  /// Build media item dengan proper thumbnail logic
  static Map<String, dynamic> buildMediaItem({
    required String name,
    required String path,
    required String service,
    String? type,
  }) {
    // Tentukan apakah ini dari kemono atau coomer API untuk thumbnail
    final apiSourceForThumbnail =
        service == 'onlyfans' || service == 'fansly' || service == 'candfans'
        ? 'coomer'
        : 'kemono';

    // Build thumbnail dari RAW path, bukan dari fullUrl
    final thumbnailUrl = getThumbnailUrlFromPath(path, apiSourceForThumbnail);

    // Build full URL untuk original media
    final fullUrl = _buildFullUrl(path, service);

    // Determine media type
    final mediaType = type ?? _getMediaType(name);

    AppLogger.debug('🖼️ MEDIA: $name');
    AppLogger.debug('🖼️ THUMB: $thumbnailUrl');
    AppLogger.debug('🖼️ FULL: $fullUrl');

    return {
      'url': fullUrl,
      'thumbnail_url': thumbnailUrl,
      'name': name,
      'type': mediaType,
    };
  }

  /// Build optimized image dengan client-side downscale (production-grade)
  static Widget buildOptimizedImage({
    required String thumbnailUrl,
    required String fullUrl,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
    // 🔥 STRATEGI DOWNSCALE
    int? cacheWidth,
    int? cacheHeight,
  }) {
    // 🔥 Solusi PRAKTIS & AMAN
    final imageUrl = (thumbnailUrl.isNotEmpty) ? thumbnailUrl : fullUrl;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      // 🔥 KUNCI NYATA: Client-side decode downscale
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      placeholder: (context, url) => placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) {
        AppLogger.debug('🔍 DEBUG: Image load error: $error for URL: $url');

        // 🔥 Lebih aman (production-grade) - fallback ke full image
        if (url == thumbnailUrl && thumbnailUrl.isNotEmpty) {
          AppLogger.debug('🔍 DEBUG: Falling back to full URL: $fullUrl');
          return CachedNetworkImage(
            imageUrl: fullUrl,
            width: width,
            height: height,
            fit: fit ?? BoxFit.cover,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            placeholder: (context, url) =>
                placeholder ?? _buildDefaultPlaceholder(),
            errorWidget: (context, url, error) =>
                errorWidget ?? _buildDefaultError(),
          );
        }

        return errorWidget ?? _buildDefaultError();
      },
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }

  /// 🔥 STRATEGI IDEAL: Latest/Grid View (ringan & cepat)
  static Widget buildLatestFeedImage({
    required String thumbnailUrl,
    required String fullUrl,
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    return buildOptimizedImage(
      thumbnailUrl: thumbnailUrl,
      fullUrl: fullUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      // 🎯 Latest / Grid View: 300x300 untuk hemat RAM & smooth scrolling
      cacheWidth: 300,
      cacheHeight: 300,
    );
  }

  /// 🔥 STRATEGI IDEAL: Detail Post (tajam & jelas)
  static Widget buildDetailPostImage({
    required String thumbnailUrl,
    required String fullUrl,
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    return buildOptimizedImage(
      thumbnailUrl: thumbnailUrl,
      fullUrl: fullUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      // 🎯 Detail Post: 800x800 untuk kualitas tinggi
      cacheWidth: 800,
      cacheHeight: 800,
    );
  }

  /// 🔥 STRATEGI IDEAL: Fullscreen Viewer (maksimal kualitas)
  static Widget buildFullscreenImage({
    required String fullUrl,
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    return CachedNetworkImage(
      imageUrl: fullUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.contain,
      // ❌ JANGAN downscale untuk fullscreen - load original
      // memCacheWidth: null,
      // memCacheHeight: null,
      placeholder: (context, url) => _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) => _buildDefaultError(),
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }

  /// Build video placeholder (consistent across screens)
  static Widget buildVideoPlaceholder({
    VoidCallback? onTap,
    double iconSize = 48.0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[800]!, Colors.grey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white54,
                size: iconSize,
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build no media placeholder
  static Widget buildNoMediaPlaceholder({
    IconData icon = Icons.image_not_supported,
    double iconSize = 32.0,
    Color? iconColor,
  }) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Icon(icon, color: iconColor ?? Colors.grey[600], size: iconSize),
      ),
    );
  }

  /// Smart thumbnail selection - cari gambar pertama
  static Map<String, dynamic>? selectThumbnailMedia(
    List<Map<String, dynamic>> mediaItems,
  ) {
    if (mediaItems.isEmpty) return null;

    final hasImage = mediaItems.any((item) => item['type'] == 'image');

    if (hasImage) {
      // Gunakan gambar pertama sebagai thumbnail
      return mediaItems.firstWhere(
        (item) => item['type'] == 'image',
        orElse: () => mediaItems.first,
      );
    } else {
      // Jika tidak ada gambar, gunakan media pertama (video)
      return mediaItems.first;
    }
  }

  /// Helper methods
  static String _getMediaType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return 'image';
    } else if ([
      'mp4',
      'webm',
      'mov',
      'avi',
      'mkv',
      'flv',
    ].contains(extension)) {
      return 'video';
    }
    return 'unknown';
  }

  static String _buildFullUrl(String path, String service) {
    if (path.isEmpty) return '';

    // Extract base path dan query parameters
    final uri = Uri.parse(
      path.startsWith('http') ? path : 'https://temp.com$path',
    );
    final basePath = uri.path;
    final queryParams = uri.hasQuery ? '?${uri.query}' : '';

    // Build CDN URL berdasarkan service
    if (service == 'onlyfans' || service == 'fansly' || service == 'candfans') {
      return 'https://n2.coomer.st$basePath$queryParams';
    } else {
      return 'https://n2.kemono.cr$basePath$queryParams';
    }
  }

  static Widget _buildDefaultPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[800]!, Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      ),
    );
  }

  static Widget _buildDefaultError() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[800]!, Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 32),
      ),
    );
  }
}
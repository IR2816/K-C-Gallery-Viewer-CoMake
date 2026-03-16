import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:kc_gallery_viewer/presentation/services/custom_cache_manager.dart';
import 'package:kc_gallery_viewer/data/services/api_header_service.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';
import 'package:kc_gallery_viewer/domain/entities/post.dart';
import 'package:kc_gallery_viewer/domain/entities/api_source.dart';
import 'package:kc_gallery_viewer/presentation/widgets/swipeable_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🎯 FINAL ImageViewer - SATU IMPLEMENTASI untuk SEMUA DOMAIN
///
/// Cara BENAR untuk gambar (Kemono & Coomer):
/// - CachedNetworkImage dengan headers
/// - Fullscreen SwipeableImageViewer dengan zoom
/// - SATU implementasi untuk semua domain
class ImageViewerFinal extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isThumbnail;
  final String? apiSource;
  final Post? post; // Tambahkan post untuk swipeable viewer

  const ImageViewerFinal({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
    this.apiSource,
    this.post, // Opsional untuk swipeable viewer
  });

  @override
  Widget build(BuildContext context) {
    final cacheManager = apiSource == 'coomer'
        ? coomerCacheManager
        : customCacheManager;
    final headers = _getHeaders();

    if (isThumbnail) {
      return GestureDetector(
        onTap: () => _openFullscreen(context),
        child: CachedNetworkImage(
          cacheManager: cacheManager,
          imageUrl: url,
          httpHeaders: headers,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildErrorWidget(error),
        ),
      );
    } else {
      return PhotoView(
        imageProvider: CachedNetworkImageProvider(
          url,
          cacheManager: cacheManager,
          headers: headers,
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => _buildPlaceholder(),
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(error),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4.0,
        // UX: Double tap zoom, swipe dismiss
        heroAttributes: PhotoViewHeroAttributes(tag: url),
      );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height ?? 200,
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Object? error) {
    AppLogger.warning('Image load failed', tag: 'ImageViewer', error: error);

    return Container(
      width: width,
      height: height ?? 200,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'Failed to load',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isThumbnail) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser, size: 16),
                label: const Text('Open in browser'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    // 🎯 JIKA ADA POST, GUNAKAN SWIPEABLE VIEWER
    if (post != null && apiSource != null) {
      final apiSourceEnum = apiSource == 'coomer'
          ? ApiSource.coomer
          : ApiSource.kemono;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              SwipeableImageViewer(post: post!, apiSource: apiSourceEnum),
        ),
      );
    } else {
      // Fallback ke single image viewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              FullscreenImageViewer(imageUrl: url, apiSource: apiSource),
        ),
      );
    }
  }

  Map<String, String> _getHeaders() {
    // Headers yang BENAR untuk 99% gambar
    if (apiSource == 'coomer') {
      return ApiHeaderService.getMediaHeaders(referer: 'https://coomer.st/');
    } else {
      return ApiHeaderService.getMediaHeaders(referer: 'https://kemono.cr/');
    }
  }

  void _openInBrowser() async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error(
        'Failed to open in browser',
        tag: 'ImageViewer',
        error: e,
      );
    }
  }
}

/// Fullscreen Image Viewer dengan UX yang nyaman
class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? apiSource;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    this.apiSource,
  });

  @override
  Widget build(BuildContext context) {
    final cacheManager = apiSource == 'coomer'
        ? coomerCacheManager
        : customCacheManager;
    final headers = apiSource == 'coomer'
        ? ApiHeaderService.getMediaHeaders(referer: 'https://coomer.st/')
        : ApiHeaderService.getMediaHeaders(referer: 'https://kemono.cr/');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Image', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: GestureDetector(
        // UX: Swipe dismiss
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 20) {
            Navigator.pop(context);
          }
        },
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(
            imageUrl,
            cacheManager: cacheManager,
            headers: headers,
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4.0,
          // UX: Double tap zoom
          enableRotation: false,
          heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        ),
      ),
    );
  }

  void _openInBrowser() async {
    try {
      final uri = Uri.parse(imageUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error(
        'Failed to open in browser',
        tag: 'ImageViewer',
        error: e,
      );
    }
  }
}

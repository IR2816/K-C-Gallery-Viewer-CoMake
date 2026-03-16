import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:kc_gallery_viewer/presentation/services/custom_cache_manager.dart';
import 'package:kc_gallery_viewer/data/services/api_header_service.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';

/// Enhanced Image Widget with caching and fullscreen zoom
class ImageWidget extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isThumbnail;
  final String? apiSource;

  const ImageWidget({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
    this.apiSource,
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
    AppLogger.warning('Image load failed', tag: 'Image', error: error);

    return Container(
      width: width,
      height: height ?? 200,
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Failed to load',
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

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            FullscreenImage(imageUrl: url, apiSource: apiSource),
      ),
    );
  }

  Map<String, String> _getHeaders() {
    if (apiSource == 'coomer') {
      return ApiHeaderService.getMediaHeaders(referer: 'https://coomer.st/');
    } else {
      return ApiHeaderService.getMediaHeaders(referer: 'https://kemono.cr/');
    }
  }
}

/// Fullscreen image viewer with PhotoView
class FullscreenImage extends StatelessWidget {
  final String imageUrl;
  final String? apiSource;

  const FullscreenImage({super.key, required this.imageUrl, this.apiSource});

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
            onPressed: () => _openInBrowser(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(
            imageUrl,
            cacheManager: cacheManager,
            headers: headers,
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4.0,
        ),
      ),
    );
  }

  void _openInBrowser() {
    // TODO: Implement url_launcher
    AppLogger.info('Opening image in browser: $imageUrl', tag: 'Image');
  }
}

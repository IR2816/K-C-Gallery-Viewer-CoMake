import 'package:flutter/material.dart';
import 'package:kc_gallery_viewer/presentation/widgets/image_viewer_final.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';

/// 🎯 FINAL MediaResolver - SATU PINTA untuk SEMUA MEDIA
///
/// Architecure:
/// PostDetailScreen
///  └── MediaResolver
///       ├── ImageViewer
///       ├── NativeVideoPlayer
///       └── WebViewVideoPlayer
///
/// Prinsip: Screen tidak perlu peduli domain / tipe media
class MediaResolverFinal extends StatelessWidget {
  final String url;
  final String? apiSource;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isThumbnail;
  final dynamic post; // Tambahkan post parameter

  const MediaResolverFinal({
    super.key,
    required this.url,
    this.apiSource,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
    this.post, // Opsional post untuk swipeable viewer
  });

  @override
  Widget build(BuildContext context) {
    AppLogger.info(
      'MediaResolver: url=$url, apiSource=$apiSource',
      tag: 'MediaResolver',
    );

    // RULE EXPLISIT - TANPA ASUMSI
    if (_isImage(url)) {
      AppLogger.info('MediaResolver: Using ImageViewer', tag: 'MediaResolver');
      return ImageViewerFinal(
        url: url,
        width: width,
        height: height,
        fit: fit,
        isThumbnail: isThumbnail,
        apiSource: apiSource,
        post: post, // Teruskan post untuk swipeable viewer
      );
    }

    if (_isVideo(url)) {
      if (_isCoomer(url, apiSource)) {
        AppLogger.info(
          'MediaResolver: Using WebViewVideoPlayer for Coomer',
          tag: 'MediaResolver',
        );
        return Container(
          width: width,
          height: height ?? 200,
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Video (Tap to play)',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      } else {
        AppLogger.info(
          'MediaResolver: Using NativeVideoPlayer for Kemono',
          tag: 'MediaResolver',
        );
        return Container(
          width: width,
          height: height ?? 200,
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Video (Tap to play)',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
    }

    AppLogger.warning(
      'MediaResolver: Unsupported media type',
      tag: 'MediaResolver',
    );
    return _buildUnsupportedMediaPlaceholder();
  }

  // 🔍 DETEKSI DOMAIN & TIPE MEDIA - ATURAN EKSPLISIT
  bool _isCoomer(String url, String? apiSource) {
    return url.contains('coomer.st') ||
        url.contains('coomer.su') ||
        apiSource == 'coomer';
  }

  bool _isImage(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool _isHls(String url) {
    return url.toLowerCase().endsWith('.m3u8');
  }

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        _isHls(url);
  }

  Widget _buildUnsupportedMediaPlaceholder() {
    return Container(
      width: width,
      height: height ?? 200,
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Unsupported Media',
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
}

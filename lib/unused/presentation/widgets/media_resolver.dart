import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../widgets/media_resolver_final.dart';
import 'package:kc_gallery_viewer/presentation/widgets/image_widget.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';

/// Simple Video Player Widget
class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool isThumbnail;
  final bool autoPlay;

  const VideoPlayerWidget({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.isThumbnail = true,
    this.autoPlay = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        if (widget.autoPlay) {
          _controller!.play();
        }
      }
    } catch (e) {
      AppLogger.error('Failed to initialize video: $e', tag: 'VideoPlayer');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),

          // Play/Pause button overlay
          if (!widget.autoPlay)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    });
                  },
                  child: Center(
                    child: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 8),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text(
              'Video load failed',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// MediaResolver - Dual strategy media player
///
/// Strategy:
/// - Images → CachedNetworkImage with PhotoView fullscreen
/// - Coomer videos → WebView (most reliable)
/// - MP4 → Native video_player with headers
/// - Fallback → Open in browser
class MediaResolver extends StatelessWidget {
  final String url;
  final String? mimeType;
  final String? apiSource;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isThumbnail;

  const MediaResolver({
    super.key,
    required this.url,
    this.mimeType,
    this.apiSource,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
  });

  @override
  Widget build(BuildContext context) {
    final lower = url.toLowerCase();

    AppLogger.info(
      'MediaResolver: url=$url, mimeType=$mimeType, apiSource=$apiSource',
      tag: 'Media',
    );

    // IMAGES
    if (_isImage(lower, mimeType)) {
      return ImageWidget(
        url: url,
        width: width,
        height: height,
        fit: fit,
        isThumbnail: isThumbnail,
        apiSource: apiSource,
      );
    }

    // COOMER VIDEOS - Enable video playback with simple player
    if (_isComerVideo(lower, apiSource)) {
      AppLogger.info(
        'MediaResolver: Enabling video playback for Coomer video (isThumbnail=$isThumbnail)',
        tag: 'Media',
      );
      return _buildSimpleVideoPlayer(url, width, height, isThumbnail);
    }

    // HLS STREAMS - Enable video playback with simple player
    if (_isHls(lower)) {
      AppLogger.info(
        'MediaResolver: Enabling video playback for HLS (isThumbnail=$isThumbnail)',
        tag: 'Media',
      );
      return _buildSimpleVideoPlayer(url, width, height, isThumbnail);
    }

    // REGULAR MP4 - Enable video playback with simple player
    AppLogger.info(
      'MediaResolver: Enabling video playback for MP4',
      tag: 'Media',
    );
    return _buildSimpleVideoPlayer(url, width, height, isThumbnail);
  }

  bool _isImage(String url, String? mimeType) {
    return url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.gif') ||
        url.endsWith('.webp') ||
        (mimeType?.startsWith('image') ?? false);
  }

  bool _isComerVideo(String url, String? apiSource) {
    return (url.contains('coomer.st') ||
            url.contains('coomer.su') ||
            apiSource == 'coomer') &&
        (url.endsWith('.mp4') || url.endsWith('.webm') || url.endsWith('.mov'));
  }

  bool _isHls(String url) {
    return url.endsWith('.m3u8') || url.contains('.m3u8?');
  }

  /// Build simple video player widget
  Widget _buildSimpleVideoPlayer(
    String url,
    double? width,
    double? height,
    bool isThumbnail,
  ) {
    if (isThumbnail) {
      // For thumbnail, show video placeholder with play button
      return Container(
        width: width,
        height: height ?? 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Try to load thumbnail image
            Positioned.fill(
              child: Image.network(
                url, // This might fail, but that's okay
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.black);
                },
              ),
            ),
            // Play button overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // For full video, show video player
      return VideoPlayerWidget(
        url: url,
        width: width,
        height: height,
        isThumbnail: false,
        autoPlay: true,
      );
    }
  }
}

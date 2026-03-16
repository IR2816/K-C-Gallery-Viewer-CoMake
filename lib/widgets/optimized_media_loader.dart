import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../utils/logger.dart';
import '../../config/domain_config.dart';
import '../data/services/api_header_service.dart';
import '../presentation/widgets/media_resolver_final.dart';

/// Optimized Media Loader for Kemono/Coomer
/// Based on technical analysis: CDN-based, direct access, no special headers required
class OptimizedMediaLoader {
  /// Build correct CDN URL for Kemono/Coomer media with fallback
  static String buildMediaUrl(
    String? path, {
    bool isThumbnail = false,
    String? apiSource,
    String quality = 'medium',
  }) {
    if (path == null || path.isEmpty) return '';

    // If already a full URL, return as is
    if (path.startsWith('http')) return path;
    if (path.startsWith('//')) return 'https:$path';

    // Remove leading slash if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Quality-based logic
    final isLowQuality = quality == 'low';
    final isHighQuality = quality == 'high';

    // Determine domain based on API source
    String domain;
    if (apiSource == 'coomer') {
      domain = DomainConfig.defaultCoomerDomain;
    } else {
      domain = DomainConfig.defaultKemonoDomain;
    }

    if (isHighQuality && !isThumbnail) {
      // Use high-quality data domain
      final cdnDomain = (apiSource == 'coomer') ? 'n4.coomer.st' : 'n4.kemono.cr';
      return 'https://$cdnDomain/data/$cleanPath';
    }

    if (isThumbnail || isLowQuality) {
      // Use thumbnail domain
      final thumbDomain = (apiSource == 'coomer') ? 'img.coomer.st' : 'img.kemono.cr';
      final stripped = cleanPath.startsWith('data/') ? cleanPath.substring(5) : cleanPath;
      return 'https://$thumbDomain/thumbnail/data/$stripped';
    }

    // Default: medium quality (usually n4 subdomain)
    final cdnDomain = (apiSource == 'coomer') ? 'n4.coomer.st' : 'n4.kemono.cr';
    final url = 'https://$cdnDomain/data/$cleanPath';

    AppLogger.mediaUrl(
      isThumbnail ? 'Thumbnail' : 'Media',
      path,
      url,
      apiSource: apiSource,
      domain: domain,
    );

    return url;
  }

  /// Get fallback URLs for a media path
  static List<String> getFallbackUrls(
    String? path, {
    bool isThumbnail = false,
    String? apiSource,
  }) {
    if (path == null || path.isEmpty) return [];

    // If already a full URL, return as is
    if (path.startsWith('http')) return [path];
    if (path.startsWith('//')) return ['https:$path'];

    // Remove leading slash if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Return all possible URL formats except the first one (already tried)
    List<String> fallbackUrls = [];

    if (isThumbnail) {
      if (cleanPath.startsWith('data/')) {
        final stripped = cleanPath.substring(5);
        if (apiSource == 'coomer') {
          fallbackUrls.addAll([
            'https://coomer.st/thumbnails/data/$stripped',
            'https://img.coomer.st/thumbnail/data/$stripped',
            'https://coomer.st/thumbnail/data/$stripped',
          ]);
        } else {
          fallbackUrls.addAll([
            'https://img.kemono.cr/thumbnails/data/$stripped',
            'https://kemono.cr/thumbnail/data/$stripped',
            'https://kemono.cr/thumbnails/data/$stripped',
          ]);
        }
      } else {
        if (apiSource == 'coomer') {
          fallbackUrls.addAll([
            'https://coomer.st/thumbnails/data/$cleanPath',
            'https://img.coomer.st/thumbnail/data/$cleanPath',
            'https://coomer.st/thumbnail/data/$cleanPath',
          ]);
        } else {
          fallbackUrls.addAll([
            'https://img.kemono.cr/thumbnails/data/$cleanPath',
            'https://kemono.cr/thumbnail/data/$cleanPath',
            'https://kemono.cr/thumbnails/data/$cleanPath',
          ]);
        }
      }
    } else {
      if (cleanPath.startsWith('data/')) {
        if (apiSource == 'coomer') {
          fallbackUrls.addAll([
            'https://coomer.st/data/$cleanPath',
            'https://cdn.coomer.st/$cleanPath',
            'https://files.coomer.st/$cleanPath',
            'https://n2.coomer.st/$cleanPath',
            'https://img.coomer.st/data/$cleanPath',
            'https://media.coomer.st/data/$cleanPath',
          ]);
        } else {
          fallbackUrls.addAll([
            'https://kemono.cr/data/$cleanPath',
            'https://cdn.kemono.cr/$cleanPath',
            'https://files.kemono.cr/$cleanPath',
            'https://n2.kemono.cr/$cleanPath',
          ]);
        }
      } else {
        if (apiSource == 'coomer') {
          fallbackUrls.addAll([
            'https://coomer.st/data/$cleanPath',
            'https://cdn.coomer.st/$cleanPath',
            'https://files.coomer.st/$cleanPath',
            'https://n2.coomer.st/$cleanPath',
            'https://img.coomer.st/data/$cleanPath',
            'https://media.coomer.st/data/$cleanPath',
          ]);
        } else {
          fallbackUrls.addAll([
            'https://kemono.cr/data/$cleanPath',
            'https://cdn.kemono.cr/$cleanPath',
            'https://files.kemono.cr/$cleanPath',
            'https://n2.kemono.cr/$cleanPath',
          ]);
        }
      }
    }

    return fallbackUrls;
  }

  /// Detect media type from file extension
  static MediaType detectMediaType(String? path) {
    if (path == null || path.isEmpty) return MediaType.unknown;

    final extension = path.toLowerCase().split('.').last;

    // Image extensions
    const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'};

    // Video extensions
    const videoExtensions = {
      'mp4',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      'mkv',
      'm4v',
    };

    if (imageExtensions.contains(extension)) {
      return MediaType.image;
    } else if (videoExtensions.contains(extension)) {
      return MediaType.video;
    }

    return MediaType.unknown;
  }
}

enum MediaType { image, video, unknown }

/// Fallback Image Widget that tries multiple URLs
class FallbackImage extends StatefulWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isThumbnail;
  final String? apiSource;
  final bool allowFallback;
  final String quality;

  const FallbackImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.isThumbnail = true,
    this.apiSource,
    this.allowFallback = true,
    this.quality = 'medium',
  });

  @override
  State<FallbackImage> createState() => _FallbackImageState();
}

class _FallbackImageState extends State<FallbackImage> {
  int _currentUrlIndex = 0;
  List<String> _urls = [];
  bool _hasError = false;

  Map<String, String> get _mediaHeaders {
    final referer = widget.apiSource == 'coomer'
        ? 'https://coomer.st/'
        : 'https://kemono.cr/';
    return ApiHeaderService.getMediaHeaders(referer: referer);
  }

  @override
  void initState() {
    super.initState();
    _loadUrls();
  }

  void _loadUrls() {
    final primaryUrl = OptimizedMediaLoader.buildMediaUrl(
      widget.imagePath,
      isThumbnail: widget.isThumbnail,
      apiSource: widget.apiSource,
      quality: widget.quality,
    );

    _urls = [primaryUrl];

    if (widget.allowFallback && widget.quality != 'low') {
      final fallbackUrls = OptimizedMediaLoader.getFallbackUrls(
        widget.imagePath,
        isThumbnail: widget.isThumbnail,
        apiSource: widget.apiSource,
      );
      _urls.addAll(fallbackUrls);
    }

    AppLogger.info(
      'FallbackImage: Trying ${_urls.length} URLs for ${widget.imagePath} (Quality: ${widget.quality})',
      tag: 'Media',
    );
  }

  void _tryNextUrl() {
    if (_currentUrlIndex < _urls.length - 1) {
      setState(() {
        _currentUrlIndex++;
        _hasError = false;
      });
    } else {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty || _hasError) {
      return widget.errorWidget ?? const Icon(Icons.broken_image);
    }

    final currentUrl = _urls[_currentUrlIndex];

    // Log current URL attempt
    AppLogger.info(
      'FallbackImage: Loading URL ${_currentUrlIndex + 1}/${_urls.length}: $currentUrl',
      tag: 'Media',
    );

    return CachedNetworkImage(
      imageUrl: currentUrl,
      httpHeaders: _mediaHeaders,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) =>
          widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 8),
                  Text(
                    'Loading Media...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      errorWidget: (context, url, error) {
        AppLogger.warning(
          'Image load failed for URL ${_currentUrlIndex + 1}/${_urls.length}',
          tag: 'Media',
          error: error,
        );

        // Try next URL
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tryNextUrl();
        });

        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 8),
                Text(
                  'Trying URL ${_currentUrlIndex + 1}/${_urls.length}...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      memCacheWidth: widget.isThumbnail ? 300 : null,
      memCacheHeight: widget.isThumbnail ? 300 : null,
    );
  }
}

/// Optimized Video Widget for Kemono/Coomer
/// Uses VideoPlayerController with direct CDN URLs
class OptimizedVideo extends StatefulWidget {
  final String? videoPath;
  final double? width;
  final double? height;
  final bool autoplay;
  final bool showControls;
  final Widget? placeholder;
  final String? apiSource;

  const OptimizedVideo({
    super.key,
    required this.videoPath,
    this.width,
    this.height,
    this.autoplay = false,
    this.showControls = true,
    this.placeholder,
    this.apiSource,
  });

  @override
  State<OptimizedVideo> createState() => _OptimizedVideoState();
}

class _OptimizedVideoState extends State<OptimizedVideo> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _loadingProgress = 'Loading Media...';

  Map<String, String> get _mediaHeaders {
    final referer = widget.apiSource == 'coomer'
        ? 'https://coomer.st/'
        : 'https://kemono.cr/';
    return ApiHeaderService.getMediaHeaders(referer: referer);
  }

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

  void _initializeVideo() async {
    final videoUrl = OptimizedMediaLoader.buildMediaUrl(
      widget.videoPath,
      apiSource: widget.apiSource,
    );

    AppLogger.mediaUrl(
      'Video',
      widget.videoPath ?? 'null',
      videoUrl,
      apiSource: widget.apiSource,
    );

    if (videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: _mediaHeaders,
      );

      // Update loading progress
      if (mounted) {
        setState(() {
          _loadingProgress = 'Connecting to video...';
        });
      }

      // Add timeout to prevent infinite loading
      await _controller!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video loading timeout after 30 seconds');
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _loadingProgress = 'Loading Media...';
        });

        if (widget.autoplay) {
          _controller!.play();
        }
      }
    } catch (e) {
      AppLogger.error('Video initialization failed', tag: 'Media', error: e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _loadingProgress = 'Failed to load video';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.grey[300],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 48),
            SizedBox(height: 8),
            Text('Video unavailable'),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height ?? 200,
            color: Colors.grey[300],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    _loadingProgress,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This may take a few seconds...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
    }

    Widget videoWidget = AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );

    if (widget.showControls) {
      videoWidget = Stack(
        alignment: Alignment.center,
        children: [
          videoWidget,
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return videoWidget;
  }
}

/// Auto-detecting Media Widget
/// Automatically chooses between image and video based on file extension
/// Now uses MediaResolverFinal for better handling
class AutoMediaWidget extends StatelessWidget {
  final String? mediaPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isThumbnail;
  final bool autoplayVideo;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? apiSource;
  final dynamic post;

  const AutoMediaWidget({
    super.key,
    required this.mediaPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
    this.autoplayVideo = false,
    this.placeholder,
    this.errorWidget,
    this.apiSource,
    this.post,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaPath == null || mediaPath!.isEmpty) {
      return errorWidget ?? const Icon(Icons.broken_image);
    }

    // Build the correct URL using existing logic
    final url = OptimizedMediaLoader.buildMediaUrl(
      mediaPath!,
      isThumbnail: isThumbnail,
      apiSource: apiSource,
    );

    // 🎯 Gunakan MediaResolverFinal - SATU PINTA untuk SEMUA MEDIA
    return MediaResolverFinal(
      url: url,
      apiSource: apiSource,
      width: width,
      height: height,
      fit: fit,
      isThumbnail: isThumbnail,
    );
  }
}

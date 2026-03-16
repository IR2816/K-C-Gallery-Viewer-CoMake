import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/entities/api_source.dart';
import '../theme/app_theme.dart';
import 'human_error_handler.dart';

/// FIXED: Media Resolver Widget dengan proper error handling
///
/// Fixes:
/// 1. Foto failed to load saat ditekan di detail post
/// 2. Proper error handling dan fallback
/// 3. Better loading states dan retry mechanisms
/// 4. Consistent dengan app theme
class MediaResolverWidgetFixed extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final ApiSource apiSource;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool autoPlay;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final bool allowZoom;

  const MediaResolverWidgetFixed({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.apiSource = ApiSource.kemono,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.autoPlay = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.allowZoom = true,
  });

  @override
  State<MediaResolverWidgetFixed> createState() =>
      _MediaResolverWidgetFixedState();
}

class _MediaResolverWidgetFixedState extends State<MediaResolverWidgetFixed> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _useWebView = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Proper headers untuk Kemono/Coomer
  static const Map<String, String> _requiredHeaders = {
    'Accept': 'text/css,*/*;q=0.1',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Cache-Control': 'max-age=0',
  };

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  @override
  void didUpdateWidget(MediaResolverWidgetFixed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resetState();
      _initializeMedia();
    }
  }

  void _resetState() {
    _disposeVideo();
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
  }

  Future<void> _initializeMedia() async {
    if (widget.url.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No URL provided';
        _isLoading = false;
      });
      return;
    }

    final isVideo = _isVideoUrl(widget.url);

    if (!isVideo) {
      // It's an image, try to load with CachedNetworkImage
      await _loadImage();
      return;
    }

    // For videos, determine player strategy
    final isCoomer = widget.apiSource == ApiSource.coomer;

    if (isCoomer) {
      // Coomer videos use WebView for maximum compatibility
      setState(() {
        _useWebView = true;
        _isLoading = false;
      });
    } else {
      // Kemono videos try video_player first
      await _initializeVideoPlayer();
    }
  }

  Future<void> _loadImage() async {
    try {
      // Pre-validate URL
      final uri = Uri.parse(widget.url);
      if (!uri.hasScheme) {
        throw Exception('Invalid URL format');
      }

      // Try to load image headers first to validate
      // This is a simple validation - in production you might want to use http package
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load image';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: _requiredHeaders,
      );

      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isLoading = false;
        });

        if (widget.autoPlay) {
          _videoController!.play();
        }
      }
    } catch (error) {
      debugPrint('Video player initialization failed: $error');

      // Fallback to WebView if video_player fails
      if (mounted) {
        setState(() {
          _useWebView = true;
          _isLoading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.webm', '.mov', '.avi', '.m4v', '.3gp'];
    return videoExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _useWebView = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Widget _buildImage() {
    if (_hasError) {
      return _buildImageErrorWidget();
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onDoubleTap: widget.allowZoom
          ? () {
              HapticFeedback.mediumImpact();
              widget.onDoubleTap?.call();
            }
          : null,
      onLongPress: () {
        HapticFeedback.heavyImpact();
        widget.onLongPress?.call();
      },
      child: CachedNetworkImage(
        imageUrl: widget.url,
        httpHeaders: _requiredHeaders,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => _buildImagePlaceholder(),
        errorWidget: (context, url, error) {
          // Update error state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.toString();
              });
            }
          });
          return _buildImageErrorWidget();
        },
        // FIXED: Add proper cache key and error handling
        memCacheWidth: widget.width?.toInt(),
        memCacheHeight: widget.height?.toInt(),
        cacheKey: '${widget.url}_${widget.apiSource}',
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
      child: Stack(
        children: [
          // Show thumbnail if available
          if (widget.thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              placeholder: (context, url) => _buildLoadingIndicator(),
              errorWidget: (context, url, error) => _buildLoadingIndicator(),
            ),

          // Loading overlay
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.black.withOpacity(0.3),
            child: _buildLoadingIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            'Failed to load image',
            style: AppTheme.captionStyle.copyWith(color: AppTheme.errorColor),
          ),
          const SizedBox(height: AppTheme.smSpacing),
          // Retry button
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: _retryLoad,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            strokeWidth: 2,
          ),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            'Loading...',
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
        ),
        child: _buildLoadingIndicator(),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
        ),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return Container(
      width: widget.width,
      height: widget.height ?? 300,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(widget.url),
            headers: _requiredHeaders,
          ),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            allowsAirPlayForMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            javaScriptEnabled: true,
            domStorageEnabled: true,
            supportZoom: false,
            useShouldOverrideUrlLoading: true,
            useOnLoadResource: true,
            // FIXED: Better settings for video playback
            allowsBackForwardNavigationGestures: false,
            disableVerticalScroll: true,
            disableHorizontalScroll: true,
          ),
          onLoadStart: (controller, url) {
            debugPrint('WebView loading started: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onLoadStop: (controller, url) {
            debugPrint('WebView loading stopped: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onReceivedError: (controller, request, error) {
            debugPrint('WebView error: $error');
            setState(() {
              _hasError = true;
              _errorMessage = error.description;
              _isLoading = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    if (_useWebView) {
      if (_hasError) {
        return _buildVideoErrorWidget();
      }
      return _buildWebView();
    }

    if (_hasError) {
      return _buildVideoErrorWidget();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        _buildVideoPlayer(),
        if (_isVideoInitialized)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(AppTheme.smRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      // Fallback to WebView if user wants
                      setState(() {
                        _useWebView = true;
                        _isVideoInitialized = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            'Failed to load video',
            style: AppTheme.captionStyle.copyWith(color: AppTheme.errorColor),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.xsSpacing),
            Text(
              _errorMessage!,
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppTheme.smSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Retry button
              IconButton(
                icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _retryLoad,
              ),
              const SizedBox(width: AppTheme.smSpacing),
              // Open in browser button
              IconButton(
                icon: Icon(Icons.open_in_browser, color: AppTheme.primaryColor),
                onPressed: _openInBrowser,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _retryLoad() async {
    HapticFeedback.mediumImpact();
    _resetState();
    await _initializeMedia();
  }

  Future<void> _openInBrowser() async {
    HapticFeedback.mediumImpact();

    try {
      // Construct proper browser URL
      final browserUrl = _constructBrowserUrl(widget.url);

      // Use url_launcher to open in browser
      // For now, just print the URL
      debugPrint('Opening in browser: $browserUrl');

      // TODO: Implement actual browser opening
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening in browser...'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open in browser'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _constructBrowserUrl(String url) {
    if (widget.apiSource == ApiSource.kemono) {
      return url.startsWith('http') ? url : 'https://kemono.cr$url';
    } else {
      return url.startsWith('http') ? url : 'https://coomer.st$url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _isVideoUrl(widget.url);

    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
        ),
        child: _buildLoadingIndicator(),
      );
    }

    if (!isVideo) {
      return _buildImage();
    }

    return _buildVideoControls();
  }
}

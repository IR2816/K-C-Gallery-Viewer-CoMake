import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/entities/api_source.dart';

class MediaResolverWidget extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final ApiSource apiSource;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool autoPlay;

  const MediaResolverWidget({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.apiSource = ApiSource.kemono,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.autoPlay = false,
  });

  @override
  State<MediaResolverWidget> createState() => _MediaResolverWidgetState();
}

class _MediaResolverWidgetState extends State<MediaResolverWidget> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _useWebView = false;

  static const Map<String, String> _requiredHeaders = {
    'Accept': 'text/css',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  @override
  void didUpdateWidget(MediaResolverWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeVideo();
      _initializeMedia();
    }
  }

  void _initializeMedia() {
    final isVideo = _isVideoUrl(widget.url);

    if (!isVideo) {
      // It's an image, use CachedNetworkImage
      return;
    }

    // For videos, determine player strategy
    final isCoomer = widget.apiSource == ApiSource.coomer;

    if (isCoomer) {
      // Coomer videos use WebView for maximum compatibility
      setState(() {
        _useWebView = true;
      });
    } else {
      // Kemono videos try video_player first
      _initializeVideoPlayer();
    }
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: _requiredHeaders,
    );

    _videoController!
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
            if (widget.autoPlay) {
              _videoController!.play();
            }
          }
        })
        .catchError((error) {
          debugPrint('Video player initialization failed: $error');
          // Fallback to WebView if video_player fails
          if (mounted) {
            setState(() {
              _useWebView = true;
            });
          }
        });
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
    return CachedNetworkImage(
      imageUrl: widget.url,
      httpHeaders: _requiredHeaders,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  Widget _buildWebView() {
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 200,
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
        ),
        onLoadStart: (controller, url) {
          debugPrint('WebView loading started: $url');
        },
        onLoadStop: (controller, url) {
          debugPrint('WebView loading stopped: $url');
        },
        onReceivedError: (controller, request, error) {
          debugPrint('WebView error: $error');
        },
      ),
    );
  }

  Widget _buildVideoControls() {
    if (_useWebView) {
      return _buildWebView();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        _buildVideoPlayer(),
        if (_isVideoInitialized)
          Positioned(
            bottom: 8,
            right: 8,
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
                    // Fallback to WebView if user wants
                    setState(() {
                      _useWebView = true;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _isVideoUrl(widget.url);

    if (!isVideo) {
      return _buildImage();
    }

    return _buildVideoControls();
  }
}

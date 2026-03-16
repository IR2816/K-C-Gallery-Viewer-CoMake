import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:kc_gallery_viewer/data/services/api_header_service.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Native Video Player using video_player
/// Simpler alternative to BetterPlayer for compatibility
class NativeVideoPlayer extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final String? apiSource;

  const NativeVideoPlayer({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.apiSource,
  });

  @override
  State<NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<NativeVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() async {
    try {
      AppLogger.info('NativeVideoPlayer: Initializing player', tag: 'Video');

      final headers = _getHeaders();
      AppLogger.info(
        'NativeVideoPlayer: Using headers: ${headers.keys.join(', ')}',
        tag: 'Video',
      );

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: headers,
      );

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
        });
      }
    } catch (e) {
      AppLogger.error(
        'NativeVideoPlayer: Failed to initialize',
        tag: 'Video',
        error: e,
      );
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Map<String, String> _getHeaders() {
    if (widget.apiSource == 'coomer') {
      return ApiHeaderService.getMediaHeaders(referer: 'https://coomer.st/');
    } else {
      return ApiHeaderService.getMediaHeaders(referer: 'https://kemono.cr/');
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
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [VideoPlayer(_controller!), _buildControls()],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return GestureDetector(
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
          color: Colors.white.withOpacity(0.8),
        ),
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
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Video unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                ElevatedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Browser'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _isInitialized = false;
    });
    _initializePlayer();
  }

  void _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error('Failed to open in browser', tag: 'Video', error: e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

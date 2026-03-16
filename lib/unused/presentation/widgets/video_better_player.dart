import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:kc_gallery_viewer/data/services/api_header_service.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// BetterPlayer widget for native video playback
/// Supports HLS, MP4 with proper headers
class BetterPlayerWidget extends StatefulWidget {
  final String url;
  final bool isHls;
  final double? width;
  final double? height;
  final String? apiSource;

  const BetterPlayerWidget({
    super.key,
    required this.url,
    this.isHls = false,
    this.width,
    this.height,
    this.apiSource,
  });

  @override
  State<BetterPlayerWidget> createState() => _BetterPlayerWidgetState();
}

class _BetterPlayerWidgetState extends State<BetterPlayerWidget> {
  BetterPlayerController? _controller;
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
      AppLogger.info(
        'BetterPlayer: Initializing ${widget.isHls ? 'HLS' : 'MP4'} player',
        tag: 'Video',
      );

      final headers = _getHeaders();
      AppLogger.info(
        'BetterPlayer: Using headers: ${headers.keys.join(', ')}',
        tag: 'Video',
      );

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.url,
        videoFormat: widget.isHls
            ? BetterPlayerVideoFormat.hls
            : BetterPlayerVideoFormat.other,
        headers: headers,
        cacheConfiguration: BetterPlayerCacheConfiguration(
          useCache: true,
          preCacheSize: 10 * 1024 * 1024, // 10MB
          maxCacheSize: 100 * 1024 * 1024, // 100MB
          maxCacheFileSize: 50 * 1024 * 1024, // 50MB
        ),
      );

      _controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false,
          aspectRatio: 16 / 9,
          fit: BoxFit.contain,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            enableProgressBar: true,
            enablePlayPause: true,
            enableMute: true,
            enableFullscreen: true,
            enableSkips: true,
            enableOverflowMenu: true,
            controlBarColor: Colors.black26,
            progressBarPlayedColor: Colors.red,
            progressBarHandleColor: Colors.red,
            progressBarBufferedColor: Colors.white24,
            progressBarBackgroundColor: Colors.white12,
          ),
          errorBuilder: (context, errorMessage) {
            setState(() {
              _hasError = true;
              _errorMessage = errorMessage;
            });
            return _buildErrorWidget();
          },
        ),
        betterPlayerDataSource: dataSource,
      );

      await _controller!.setupDataSource();

      setState(() {
        _isInitialized = true;
      });

      _controller!.addEventsListener((event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          AppLogger.error(
            'BetterPlayer: Exception occurred',
            tag: 'Video',
            error: event,
          );
          setState(() {
            _hasError = true;
            _errorMessage = 'Playback error occurred';
          });
        }
      });
    } catch (e) {
      AppLogger.error(
        'BetterPlayer: Failed to initialize',
        tag: 'Video',
        error: e,
      );
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
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
      child: BetterPlayer(controller: _controller!),
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

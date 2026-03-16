// app_video_player.dart
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../../data/services/api_header_service.dart';
import '../theme/app_theme.dart';
import 'video_webview.dart';

class AppVideoPlayer extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool autoplay;
  final bool showControls;
  final bool showLoading;
  final bool showError;
  final bool allowWebViewFallback;
  final String? apiSource;
  final ValueChanged<bool>? onLoadingChanged;
  final ValueChanged<String?>? onError;

  const AppVideoPlayer({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.autoplay = false,
    this.showControls = true,
    this.showLoading = true,
    this.showError = true,
    this.allowWebViewFallback = true,
    this.apiSource,
    this.onLoadingChanged,
    this.onError,
  });

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _useWebViewFallback = false;
  List<String> _urlCandidates = const [];

  @override
  void initState() {
    super.initState();
    _urlCandidates = _buildUrlCandidates(widget.url, widget.apiSource);
    _initializePlayer();
  }

  @override
  void didUpdateWidget(AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _urlCandidates = _buildUrlCandidates(widget.url, widget.apiSource);
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _chewieController?.dispose();
    _chewieController = null;
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializePlayer() async {
    _setLoading(true);
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _useWebViewFallback = false;
      _isInitialized = false;
    });

    try {
      bool initialized = false;
      final candidates = _urlCandidates.isNotEmpty
          ? _urlCandidates
          : [widget.url];

      for (final url in candidates) {
        final ok = await _tryInitialize(url);
        if (!mounted) return;
        if (ok) {
          initialized = true;
          break;
        }
      }

      if (!initialized) {
        throw Exception('Unable to load video from available domains');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        // Fallback to webview on any native player failure
        if (widget.allowWebViewFallback) {
          debugPrint(
            'AppVideoPlayer: Native player failed ($e), falling back to WebView.',
          );
          _useWebViewFallback = true;
          _hasError = false;
        }
      });
      _setLoading(false);
      widget.onError?.call(_errorMessage);
    }
  }

  Future<bool> _tryInitialize(String url) async {
    try {
      _disposeController();
      final headers = _getHeaders(url, widget.apiSource);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: false),
      );
      _controller = controller;

      await controller.initialize().timeout(const Duration(seconds: 25));
      if (!mounted) return false;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: widget.autoplay,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: widget.showControls,
        zoomAndPan: true, // Allow zooming into video
        bufferingBuilder: (context) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        },
        showControlsOnInitialize: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
          handleColor: AppTheme.primaryColor,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
      );

      setState(() {
        _isInitialized = true;
      });
      _setLoading(false);
      return true;
    } catch (_) {
      _disposeController();
      return false;
    }
  }

  void _setLoading(bool value) {
    widget.onLoadingChanged?.call(value);
  }

  bool _isCoomerSource(String url, String? apiSource) {
    final source = (apiSource ?? '').toLowerCase();
    final lowerUrl = url.toLowerCase();
    return source == 'coomer' || lowerUrl.contains('coomer.');
  }

  bool _isKemonoSource(String url, String? apiSource) {
    final source = (apiSource ?? '').toLowerCase();
    final lowerUrl = url.toLowerCase();
    return source == 'kemono' || lowerUrl.contains('kemono.');
  }

  // ignore: unused_element
  bool _isWebViewPreferred(String url, String? apiSource) {
    return _isCoomerSource(url, apiSource) || _isKemonoSource(url, apiSource);
  }

  List<String> _buildUrlCandidates(String url, String? apiSource) {
    if (url.isEmpty) return const [];
    final isCoomer = _isCoomerSource(url, apiSource);
    final isKemono = _isKemonoSource(url, apiSource);
    if (!isCoomer && !isKemono) return [url];

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return [url];
    }

    final hosts = <String>[];
    if (isCoomer) {
      hosts.addAll([
        'n1.coomer.st',
        'n2.coomer.st',
        'n3.coomer.st',
        'n4.coomer.st',
        'coomer.st',
        'cdn.coomer.st',
        'files.coomer.st',
        'media.coomer.st',
      ]);
    }
    if (isKemono) {
      hosts.addAll([
        'kemono.cr',
        'n1.kemono.cr',
        'n2.kemono.cr',
        'n3.kemono.cr',
        'n4.kemono.cr',
      ]);
    }

    final unique = <String>{};
    for (final host in hosts) {
      final rebuilt = uri.replace(host: host).toString();
      unique.add(rebuilt);
    }
    unique.add(url);
    return unique.toList();
  }

  Map<String, String> _getHeaders(String url, String? apiSource) {
    final lowerUrl = url.toLowerCase();
    final source = (apiSource ?? '').toLowerCase();
    final isCoomer = source == 'coomer' || lowerUrl.contains('coomer.');
    final isKemono = source == 'kemono' || lowerUrl.contains('kemono.');
    final referer = isCoomer
        ? 'https://coomer.st/'
        : isKemono
        ? 'https://kemono.cr/'
        : 'https://kemono.cr/';
    final headers = ApiHeaderService.getMediaHeaders(referer: referer);
    if (isCoomer) {
      headers['Origin'] = 'https://coomer.st';
      headers['Accept-Language'] = 'en-US,en;q=0.9';
      headers['Accept-Encoding'] = 'gzip, deflate, br';
      headers['Connection'] = 'keep-alive';
    }
    if (isKemono) {
      headers['Origin'] = 'https://kemono.cr';
    }
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    if (_useWebViewFallback) {
      return _buildSized(
        centerChild: true,
        child: VideoWebView(
          url: widget.url,
          width: widget.width,
          height: widget.height,
          fallbackUrls: _urlCandidates,
        ),
      );
    }

    if (_hasError) {
      return widget.showError ? _buildError() : _buildFallbackBox();
    }

    if (!_isInitialized) {
      return widget.showLoading ? _buildLoading() : _buildFallbackBox();
    }

    return _buildSized(
      child: Chewie(controller: _chewieController!),
      centerChild: true,
    );
  }

  Widget _buildLoading() {
    return _buildSized(
      child: Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              SizedBox(height: 12),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackBox() {
    return _buildSized(child: Container(color: Colors.black));
  }

  Widget _buildError() {
    return _buildSized(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 36),
            const SizedBox(height: 8),
            const Text(
              'Video unavailable',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: _initializePlayer,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Retry'),
                ),
                if (widget.allowWebViewFallback)
                  TextButton(
                    onPressed: () {
                      setState(() => _useWebViewFallback = true);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Use WebView'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSized({required Widget child, bool centerChild = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final hasBoundedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final hasBoundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final width =
            widget.width ??
            (hasBoundedWidth ? constraints.maxWidth : media.width);
        final height =
            widget.height ??
            (hasBoundedHeight ? constraints.maxHeight : media.height);

        return SizedBox(
          width: width,
          height: height,
          child: centerChild ? Center(child: child) : child,
        );
      },
    );
  }
}

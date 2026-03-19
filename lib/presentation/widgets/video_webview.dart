//video_webview.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';

/// WebView-based video player optimized for Coomer/Kemono CDN
/// Stable, deterministic, and safe against infinite retry
class VideoWebView extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool isThumbnail;
  final List<String>? fallbackUrls;

  const VideoWebView({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.isThumbnail = false,
    this.fallbackUrls,
  });

  @override
  State<VideoWebView> createState() => _VideoWebViewState();
}

enum _VideoLoadState { loading, ready, error }

class _VideoWebViewState extends State<VideoWebView> {
  Timer? _timeout;
  _VideoLoadState _state = _VideoLoadState.loading;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_state == _VideoLoadState.loading) {
        setState(() => _state = _VideoLoadState.error);
        AppLogger.warning('VideoWebView timeout after 15s', tag: 'Video');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _VideoLoadState.error) {
      return _buildError();
    }

    final baseUrl = _resolveBaseUrl(widget.url);
    return ClipRect(
      child: SizedBox(
        width: widget.width,
        height: widget.height ?? 200,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            ClipRect(
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: _buildHtml(),
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                  baseUrl: WebUri(baseUrl),
                  historyUrl: WebUri(baseUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  transparentBackground: true,
                  supportZoom: false,
                  useShouldOverrideUrlLoading: false,
                  useHybridComposition: true,
                  disableContextMenu: true,
                  hardwareAcceleration: false,
                  rendererPriorityPolicy: RendererPriorityPolicy(
                    rendererRequestedPriority:
                        RendererPriority.RENDERER_PRIORITY_IMPORTANT,
                    waivedWhenNotVisible: false,
                  ),
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  thirdPartyCookiesEnabled: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  domStorageEnabled: true,
                ),
                onWebViewCreated: (controller) {
                  AppLogger.info('WebView created', tag: 'Video');

                  // Tambahkan JavaScript handler untuk video ready signal
                  controller.addJavaScriptHandler(
                    handlerName: 'videoReady',
                    callback: (args) {
                      if (!mounted) return;
                      _timeout?.cancel();
                      setState(() => _state = _VideoLoadState.ready);

                      final reason = args.isNotEmpty ? args.first : 'unknown';
                      AppLogger.info('Video unlocked: $reason', tag: 'Video');
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  _startTimeout();
                  setState(() => _state = _VideoLoadState.loading);
                },
                onLoadStop: (controller, url) async {
                  // HARD UNLOCK after HTML load - JS bridge tidak reliable untuk cross-origin video
                  if (!mounted) return;

                  // Delay kecil untuk allow metadata fetch
                  await Future.delayed(const Duration(milliseconds: 400));

                  if (_state == _VideoLoadState.loading) {
                    setState(() => _state = _VideoLoadState.ready);
                    AppLogger.warning(
                      'Video unlocked by onLoadStop fallback (JS bridge unavailable)',
                      tag: 'Video',
                    );
                  }
                },
                onReceivedError: (controller, request, error) {
                  var isMainFrame = true;
                  try {
                    final value = (request as dynamic).isForMainFrame;
                    if (value is bool) isMainFrame = value;
                  } catch (_) {
                    // Keep default true when property is unavailable.
                  }
                  if (!isMainFrame) return;
                  _timeout?.cancel();
                  setState(() => _state = _VideoLoadState.error);
                },
                onConsoleMessage: (_, message) {
                  AppLogger.info('WebView: ${message.message}', tag: 'Video');
                },
              ),
            ),
            if (_state == _VideoLoadState.loading) _buildLoading(),
          ],
        ),
      ),
    );
  }

  // =========================
  // HTML + JavaScript (SAFE)
  // =========================

  String _buildHtml() {
    final isThumbnail = widget.isThumbnail;
    final sourceUrls = <String>[widget.url, ...?widget.fallbackUrls];
    final uniqueSources = <String>[];
    final seen = <String>{};
    for (final url in sourceUrls) {
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      uniqueSources.add(url);
    }
    final sourcesJson = jsonEncode(uniqueSources);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html, body {
    margin: 0;
    padding: 0;
    background: #000;
    width: 100vw;
    height: 100vh;
    overflow: hidden;
    position: fixed;
    top: 0;
    left: 0;
  }
  body {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  #wrap {
    width: 100%;
    height: 100%;
    overflow: hidden;
    background: #000;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  video {
    background: #000;
    object-fit: contain;
    object-position: center center;
    display: block;
    width: 100%;
    height: 100%;
    max-width: 100%;
    max-height: 100%;
    margin: 0;
    padding: 0;
    border: 0;
  }
</style>
</head>
<body>

<div id="wrap">
  <video
    id="player"
    controls
    playsinline
    webkit-playsinline
    preload="auto"
    ${isThumbnail ? 'muted' : ''}
  ></video>
</div>

<script>
  const video = document.getElementById('player');
  const sources = $sourcesJson;
  let sourceIndex = 0;
  let readySent = false;

  function setSource(index) {
    if (!sources.length) {
      notifyReady('no-source');
      return;
    }
    sourceIndex = index;
    video.src = sources[sourceIndex];
    video.load();
    ${isThumbnail ? '' : "video.play().catch(() => {});"}
    console.log('Video source:', video.src);
  }

  function notifyReady(reason) {
    if (readySent) return;
    readySent = true;
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('videoReady', reason);
    }
    console.log('Video READY:', reason);
  }

  // Most reliable events
  video.addEventListener('loadedmetadata', () => notifyReady('loadedmetadata'));
  video.addEventListener('loadeddata', () => notifyReady('loadeddata'));
  video.addEventListener('canplay', () => notifyReady('canplay'));
  video.addEventListener('canplaythrough', () => notifyReady('canplaythrough'));
  video.addEventListener('playing', () => notifyReady('playing'));

  video.addEventListener('error', () => {
    if (sourceIndex + 1 < sources.length) {
      console.log('Source failed, trying fallback:', sourceIndex + 1);
      setSource(sourceIndex + 1);
      return;
    }
    console.log('Video ERROR: no more fallbacks');
    notifyReady('error');
  });

  video.addEventListener('waiting', () => console.log('Video waiting/buffering'));
  video.addEventListener('stalled', () => console.log('Video stalled'));
  video.addEventListener('progress', () => console.log('Video progress'));

  // Ultimate fallback (always unlock UI)
  setTimeout(() => {
    notifyReady('forced-timeout');
  }, 2500);

  // Thumbnail safeguard
  if (${widget.isThumbnail}) {
    video.pause();
    video.currentTime = 0;
  }

  setSource(0);
</script>

</body>
</html>
''';
  }

  String _resolveBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'https://kemono.cr';
    final host = uri.host.toLowerCase();

    if (host.contains('coomer.')) {
      return 'https://coomer.st';
    }
    if (host.contains('kemono.cr')) {
      return 'https://kemono.cr';
    }
    if (host.contains('kemono.su')) {
      return 'https://kemono.su';
    }

    return '${uri.scheme}://${uri.host}';
  }

  // =========================
  // UI Helpers
  // =========================

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isThumbnail ? 'Loading preview...' : 'Loading video...',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Coomer CDN may be slow',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: Colors.white, size: 48),
            SizedBox(height: 12),
            Text('Failed to load video', style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            Text(
              'Try opening in browser',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

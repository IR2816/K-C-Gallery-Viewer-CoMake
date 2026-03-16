import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String fileName;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.fileName,
  });

  @override
  _FullscreenImageViewerState createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  TransformationController? _transformationController;
  TapDownDetails? _doubleTapDetails;
  Offset? _lastPanOffset;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main image viewer
          Positioned.fill(
            child: Center(
              child: Hero(
                tag: widget.heroTag,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl, // ✅ LANGSUNG PAKAI FULL URL
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'URL: $url', // ✅ DEBUG: Show actual URL
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // Top bar with controls (drawn above the image)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
                child: Row(
                  children: [
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                    ),
                    const Spacer(),
                    // Download button
                    IconButton(
                      onPressed: () {
                        // TODO: Implement download
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Download not implemented yet'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, color: Colors.white),
                      tooltip: 'Download',
                    ),
                    // Share button
                    IconButton(
                      onPressed: () {
                        // TODO: Implement share
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Share not implemented yet'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, color: Colors.white),
                      tooltip: 'Share',
                    ),
                    const SizedBox(width: 16),
                    // More options
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.white,
                      onSelected: (String value) {
                        switch (value) {
                          case 'reset':
                            _transformationController?.value =
                                Matrix4.identity();
                            break;
                          case 'fit_to_screen':
                            _transformationController?.value =
                                Matrix4.identity();
                            break;
                          case 'rotate_left':
                            final current = _transformationController?.value;
                            if (current != null) {
                              final rotation = Matrix4.rotationZ(0.1);
                              _transformationController?.value =
                                  current * rotation;
                            }
                            break;
                          case 'rotate_right':
                            final current = _transformationController?.value;
                            if (current != null) {
                              final rotation = Matrix4.rotationZ(-0.1);
                              _transformationController?.value =
                                  current * rotation;
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'reset',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Reset',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'fit_to_screen',
                          child: Row(
                            children: [
                              Icon(Icons.fullscreen, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Fit to Screen',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'rotate_left',
                          child: Row(
                            children: [
                              Icon(Icons.rotate_left, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Rotate Left',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'rotate_right',
                          child: Row(
                            children: [
                              Icon(Icons.rotate_right, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Rotate Right',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom info bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.fileName, // ✅ PAKAI FILE NAME PARAMETER
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

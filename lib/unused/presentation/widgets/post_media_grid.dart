import 'package:flutter/material.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import 'media_resolver_widget.dart';

class PostMediaGrid extends StatelessWidget {
  final Post post;
  final ApiSource apiSource;
  final int crossAxisCount;
  final double childAspectRatio;

  const PostMediaGrid({
    super.key,
    required this.post,
    required this.apiSource,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final mediaUrls = _extractMediaUrls();

    if (mediaUrls.isEmpty) {
      return const Center(child: Text('No media available'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: mediaUrls.length,
      itemBuilder: (context, index) {
        final mediaUrl = mediaUrls[index];
        final isVideo = _isVideoUrl(mediaUrl);

        return GestureDetector(
          onTap: () {
            _showMediaDialog(context, mediaUrl, isVideo);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: MediaResolverWidget(
              url: mediaUrl,
              apiSource: apiSource,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }

  List<String> _extractMediaUrls() {
    final urls = <String>[];

    // DEBUG: Log media extraction
    print('=== DEBUG: POST MEDIA EXTRACTION ===');
    print('PostMediaGrid: post.attachments.length=${post.attachments.length}');
    print('PostMediaGrid: post.file.length=${post.file.length}');

    // Add file attachments
    for (final file in post.file) {
      print('PostMediaGrid: processing file=${file.name}, path=${file.path}');
      if (file.name.endsWith('.jpg') ||
          file.name.endsWith('.jpeg') ||
          file.name.endsWith('.png') ||
          file.name.endsWith('.gif') ||
          file.name.endsWith('.webp') ||
          file.name.endsWith('.mp4') ||
          file.name.endsWith('.webm') ||
          file.name.endsWith('.mov')) {
        urls.add(file.path);
        print('PostMediaGrid: ADDED file URL=${file.path}');
      } else {
        print('PostMediaGrid: SKIPPED file (not media)=${file.name}');
      }
    }

    // Add attachments
    for (final attachment in post.attachments) {
      print(
        'PostMediaGrid: processing attachment=${attachment.name}, path=${attachment.path}',
      );
      if (attachment.name.endsWith('.jpg') ||
          attachment.name.endsWith('.jpeg') ||
          attachment.name.endsWith('.png') ||
          attachment.name.endsWith('.gif') ||
          attachment.name.endsWith('.webp') ||
          attachment.name.endsWith('.mp4') ||
          attachment.name.endsWith('.webm') ||
          attachment.name.endsWith('.mov')) {
        urls.add(attachment.path);
        print('PostMediaGrid: ADDED attachment URL=${attachment.path}');
      } else {
        print(
          'PostMediaGrid: SKIPPED attachment (not media)=${attachment.name}',
        );
      }
    }

    print('PostMediaGrid: final media URLs count=${urls.length}');
    for (int i = 0; i < urls.length; i++) {
      print('PostMediaGrid: media URL $i=${urls[i]}');
    }
    print('=== END POST MEDIA DEBUG ===');

    return urls;
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.webm', '.mov', '.avi', '.m4v', '.3gp'];
    return videoExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  void _showMediaDialog(BuildContext context, String mediaUrl, bool isVideo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: MediaResolverWidget(
                  url: mediaUrl,
                  apiSource: apiSource,
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: isVideo
                      ? MediaQuery.of(context).size.height * 0.7
                      : null,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

class PostBodyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool stripHtml;

  const PostBodyText({
    super.key,
    required this.text,
    this.style,
    this.stripHtml = true,
  });

  @override
  Widget build(BuildContext context) {
    final processedText = stripHtml ? _stripHtml(text) : text;

    if (processedText.isEmpty) {
      return const SizedBox.shrink();
    }

    // Debug: Print text to see what we're working with
    final debugText = processedText.length > 100
        ? processedText.substring(0, 100)
        : processedText;
    print('PostBodyText: Processing text: $debugText');

    return SelectableLinkify(
      text: processedText,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
      linkStyle: TextStyle(
        color: Colors.blueAccent,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w500,
      ),
      onOpen: (link) async {
        print('Link tapped: ${link.url}');
        await _handleLinkTap(context, link.url);
      },
    );
  }

  String _stripHtml(String htmlText) {
    try {
      final document = parser.parse(htmlText);
      final String plainText = _extractTextFromNode(document.body!);
      return plainText.trim();
    } catch (e) {
      // Fallback to simple regex if HTML parsing fails
      return htmlText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
  }

  String _extractTextFromNode(dom.Node node) {
    if (node is dom.Text) {
      return node.text ?? '';
    }

    if (node is dom.Element) {
      final buffer = StringBuffer();

      // Handle special cases for certain elements
      switch (node.localName?.toLowerCase()) {
        case 'br':
        case 'p':
        case 'div':
          buffer.writeln();
          break;
        case 'li':
          buffer.writeln('• ');
          break;
      }

      // Recursively extract text from child nodes
      for (final child in node.nodes) {
        buffer.write(_extractTextFromNode(child));
      }

      // Add spacing after block elements
      if (node.localName?.toLowerCase() == 'p' ||
          node.localName?.toLowerCase() == 'div') {
        buffer.writeln();
      }

      return buffer.toString();
    }

    return '';
  }

  Future<void> _handleLinkTap(BuildContext context, String url) async {
    try {
      // Clean and validate URL
      final cleanUrl = _cleanUrl(url);

      if (cleanUrl.isEmpty) {
        _showErrorDialog(context, 'Invalid link format');
        return;
      }

      final uri = Uri.parse(cleanUrl);

      // Check if it's a media file
      if (_isMediaFile(cleanUrl)) {
        _showMediaLinkDialog(context, cleanUrl);
        return;
      }

      // Check if URL is valid and can be launched
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog(context, 'Cannot open this link');
      }
    } catch (e) {
      _showErrorDialog(context, 'Invalid link format');
    }
  }

  /// Clean and validate URL (same as in PostDetailScreen)
  String _cleanUrl(String url) {
    print('PostBodyText - Cleaning URL: $url');

    // Remove trailing punctuation that's not part of URL
    url = url.replaceAll(RegExp(r'[.,;:!?)}\]\"]+$'), '');

    // Remove leading punctuation - simpler pattern
    url = url.replaceAll(RegExp(r'^[({\[]+'), '');

    // Remove common trailing patterns that aren't part of URL
    url = url.replaceAll(RegExp(r'(?:\s+)?(?:\.\.\.)?$'), '');

    print('PostBodyText - After punctuation removal: $url');

    // Ensure URL has valid structure
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      print('PostBodyText - Invalid: Does not start with http/https');
      return '';
    }

    // Basic validation - check if URL has at least domain and TLD
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      print('PostBodyText - Invalid: Cannot parse URI or no authority');
      return '';
    }

    print('PostBodyText - Valid URL: $url');
    return url;
  }

  bool _isMediaFile(String url) {
    final mediaExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.mp3',
      '.wav',
      '.ogg',
      '.flac',
      '.aac',
      '.zip',
      '.rar',
      '.7z',
      '.tar',
      '.gz',
    ];

    return mediaExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  void _showMediaLinkDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Media Link'),
        content: Text(
          'This appears to be a media file link:\n\n$url\n\n'
          'Media files should be accessed through the media viewer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Copy to clipboard for user convenience
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

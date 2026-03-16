import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'dart:io';
import '../../utils/logger.dart';

/// Custom Tabs Service untuk download yang stabil
///
/// Menggunakan Chrome Custom Tabs (Android) dan SFSafariViewController (iOS)
/// untuk memberikan browser reliability tanpa meninggalkan tab permanen
class CustomTabsService {
  /// Open URL in Custom Tab untuk download
  static Future<bool> openUrlForDownload({
    required String url,
    required BuildContext context,
    String? title,
  }) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Opening Custom Tabs for download...')),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Try Custom Tabs first (TRUE Custom Tabs implementation)
      try {
        await custom_tabs.launchUrl(
          Uri.parse(url),
          customTabsOptions: custom_tabs.CustomTabsOptions(
            colorSchemes: custom_tabs.CustomTabsColorSchemes.defaults(
              toolbarColor: Theme.of(context).colorScheme.surface,
              navigationBarColor: Theme.of(context).colorScheme.surface,
            ),
            shareState: custom_tabs.CustomTabsShareState.off,
            urlBarHidingEnabled: true,
            showTitle: true,
          ),
          safariVCOptions: custom_tabs.SafariViewControllerOptions(
            preferredBarTintColor: Theme.of(context).colorScheme.surface,
            preferredControlTintColor: Theme.of(context).colorScheme.onSurface,
            barCollapsingEnabled: true,
            entersReaderIfAvailable: false,
            dismissButtonStyle:
                custom_tabs.SafariViewControllerDismissButtonStyle.close,
          ),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.security, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Custom Tabs opened for download\nClose tab to return to app',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Got it',
                textColor: Colors.white,
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ),
          );
        }
        return true;
      } catch (e) {
        AppLogger.warning(
          'CustomTabsService: Custom Tabs failed, using external browser',
          tag: 'CustomTabs',
        );
        // Fallback to external browser
        if (!context.mounted) {
          return false;
        }
        return await openInExternalBrowser(url: url, context: context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open browser: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () =>
                  openUrlForDownload(url: url, context: context, title: title),
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Open URL in external browser (fallback)
  static Future<bool> openInExternalBrowser({
    required String url,
    required BuildContext context,
  }) async {
    try {
      final launched = await url_launcher.launchUrl(
        Uri.parse(url),
        mode: url_launcher.LaunchMode.externalApplication,
      );

      if (launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.open_in_browser, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Using external browser for download\nCheck your downloads folder',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }

      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open external browser: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () =>
                  openInExternalBrowser(url: url, context: context),
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Get browser-like headers untuk compatibility
  static Map<String, String> getBrowserHeaders() {
    return {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept":
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.5",
      "Accept-Encoding": "gzip, deflate",
      "Connection": "keep-alive",
      "Upgrade-Insecure-Requests": "1",
      "Sec-Fetch-Dest": "document",
      "Sec-Fetch-Mode": "navigate",
      "Sec-Fetch-Site": "none",
      "Cache-Control": "max-age=0",
    };
  }

  /// Check if Custom Tabs is available
  static Future<bool> isCustomTabsAvailable() async {
    try {
      // For flutter_custom_tabs 2.4+, always return true for Android/iOS
      // The library will handle fallback automatically
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  /// Get browser info untuk debugging
  static Map<String, dynamic> getBrowserInfo() {
    return {
      'platform': Platform.isAndroid ? 'Android' : 'iOS',
      'recommendedMethod': 'Custom Tabs',
      'fallbackMethod': 'External Browser',
      'advantages': [
        'Dianggap browser asli oleh server',
        'Tidak meninggalkan tab permanen',
        'Auto-close setelah download',
        'UX tetap di dalam app',
        'Browser reliability',
      ],
    };
  }
}

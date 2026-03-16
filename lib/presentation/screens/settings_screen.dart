import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Providers
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../providers/data_usage_tracker.dart';

// Theme
import '../theme/app_theme.dart';
import '../services/custom_cache_manager.dart';

// Domain
import '../../domain/entities/api_source.dart';

// Screens
import 'data_usage_dashboard.dart';

/// 🎯 Settings Screen - Kontrol & Kenyamanan User
///
/// Prinsip:
/// - Ringkas & berguna
/// - Kategori jelas
/// - Tidak perlu scroll panjang
/// - Setiap toggle punya efek nyata
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<String>? _cacheSizeFuture;

  @override
  void initState() {
    super.initState();
    _cacheSizeFuture = _calculateCacheSize();
  }

  Future<String> _calculateCacheSize() async {
    final kemonoBytes = await customCacheManager.store.getCacheSize();
    final coomerBytes = await coomerCacheManager.store.getCacheSize();
    final totalBytes = kemonoBytes + coomerBytes;
    return _formatBytes(totalBytes);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: const Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: Colors.white,
                  letterSpacing: -1.2,
                ),
              ),
            ),
            Text(
              'Customize your experience',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.getSecondaryTextColor(
                  context,
                ).withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withValues(alpha: 0.98),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: -70,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryAccent.withValues(alpha: 0.06),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildAppProfileCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Appearance'),
                _buildAppearanceSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Content & Filters'),
                _buildContentFiltersSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Feed Layout'),
                _buildFeedLayoutSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Media & Playback'),
                _buildMediaPlaybackSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Download Settings'),
                _buildDownloadSettingsSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Data & Storage'),
                _buildDataStorageSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('About'),
                _buildAboutSection(),
                const SizedBox(height: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.getSecondaryTextColor(
                context,
              ).withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.getBorderColor(context).withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.1
                  : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }

  Widget _buildAppProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.getBorderColor(context).withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.08,
            ),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // App icon with glow
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          // App info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'K/C Viewer',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: AppTheme.getPrimaryTextColor(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'PREMIUM EDITION',
                    style: TextStyle(
                      color: AppTheme.primaryLightColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return _buildSettingsCard(
          context,
          Column(
            children: [
              // Theme Selection
              ListTile(
                leading: const Icon(
                  Icons.palette_rounded,
                  size: 20,
                  color: Colors.indigoAccent,
                ),
                title: const Text(
                  'Theme',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_getThemeDisplayName(themeProvider.themeMode)),
                trailing: DropdownButton<ThemeMode>(
                  value: themeProvider.themeMode,
                  onChanged: (ThemeMode? newTheme) {
                    if (newTheme != null) {
                      themeProvider.setThemeMode(newTheme);
                    }
                  },
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, indent: 56),

              // Text Size
              ListTile(
                leading: const Icon(
                  Icons.format_size_rounded,
                  size: 20,
                  color: Colors.amber,
                ),
                title: const Text(
                  'Text Size',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _getTextSizeDisplayName(themeProvider.textScale),
                ),
                trailing: DropdownButton<double>(
                  value: themeProvider.textScale,
                  onChanged: (double? newTextScale) {
                    if (newTextScale != null) {
                      themeProvider.setTextScale(newTextScale);
                    }
                  },
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(value: 0.85, child: Text('Small')),
                    DropdownMenuItem(value: 1.0, child: Text('Normal')),
                    DropdownMenuItem(value: 1.15, child: Text('Large')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentFiltersSection() {
    return Consumer2<SettingsProvider, TagFilterProvider>(
      builder: (context, settingsProvider, tagFilterProvider, child) {
        return _buildSettingsCard(
          context,
          Column(
            children: [
              // Blocked Tags
              ListTile(
                leading: const Icon(
                  Icons.tag_rounded,
                  size: 20,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  'Blocked Tags',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${tagFilterProvider.blacklist.length} tags currently blocked',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _showBlockedTagsScreen(),
              ),

              const Divider(height: 1, indent: 56),

              // Hide NSFW
              SwitchListTile(
                secondary: const Icon(
                  Icons.explicit_rounded,
                  size: 20,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Hide NSFW Content',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Safely browse in public'),
                activeThumbColor: AppTheme.primaryColor,
                value: settingsProvider.hideNsfw,
                onChanged: (bool value) => settingsProvider.setHideNsfw(value),
              ),

              const Divider(height: 1, indent: 56),

              // Services Filter
              ListTile(
                leading: const Icon(
                  Icons.hub_rounded,
                  size: 20,
                  color: Colors.teal,
                ),
                title: const Text(
                  'Preferred Source',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _getServiceDisplayName(settingsProvider.defaultApiSource),
                ),
                trailing: DropdownButton<ApiSource>(
                  value: settingsProvider.defaultApiSource,
                  onChanged: (ApiSource? newSource) {
                    if (newSource != null) {
                      settingsProvider.setDefaultApiSource(newSource);
                    }
                  },
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: ApiSource.values.map((source) {
                    return DropdownMenuItem(
                      value: source,
                      child: Text(source.name.toUpperCase()),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedLayoutSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return _buildSettingsCard(
          context,
          Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.grid_view_rounded,
                  size: 20,
                  color: Colors.orangeAccent,
                ),
                title: const Text(
                  'Latest Card Style',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _getPostCardStyleDisplayName(
                    settingsProvider.latestPostCardStyle,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: settingsProvider.latestPostCardStyle,
                  onChanged: (String? newStyle) {
                    if (newStyle != null) {
                      settingsProvider.setLatestPostCardStyle(newStyle);
                    }
                  },
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(value: 'rich', child: Text('Rich')),
                    DropdownMenuItem(value: 'compact', child: Text('Compact')),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(
                  Icons.view_column_rounded,
                  size: 20,
                  color: Colors.cyanAccent,
                ),
                title: const Text(
                  'Layout Columns',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${settingsProvider.latestPostsColumns} columns',
                ),
                trailing: DropdownButton<int>(
                  value: settingsProvider.latestPostsColumns,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setLatestPostsColumns(newValue);
                    }
                  },
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaPlaybackSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return _buildSettingsCard(
          context,
          Column(
            children: [
              // Autoplay Video
              SwitchListTile(
                secondary: const Icon(
                  Icons.slow_motion_video_rounded,
                  size: 20,
                  color: Colors.purpleAccent,
                ),
                title: const Text(
                  'Autoplay Videos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Play automatically in feed'),
                activeThumbColor: AppTheme.primaryColor,
                value: settingsProvider.autoplayVideo,
                onChanged: (bool value) =>
                    settingsProvider.setAutoplayVideo(value),
              ),

              const Divider(height: 1, indent: 56),

              // Use Thumbnails
              SwitchListTile(
                secondary: const Icon(
                  Icons.image_aspect_ratio_rounded,
                  size: 20,
                  color: Colors.greenAccent,
                ),
                title: const Text(
                  'Optimize Images',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Use thumbnails to save data'),
                activeThumbColor: AppTheme.primaryColor,
                value: settingsProvider.loadThumbnails,
                onChanged: (bool value) =>
                    settingsProvider.setLoadThumbnails(value),
              ),

              const Divider(height: 1, indent: 56),

              // Image Fit Mode
              ListTile(
                leading: const Icon(
                  Icons.aspect_ratio_rounded,
                  size: 20,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  'Image Fit Mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _getImageFitDisplayName(settingsProvider.imageFitMode),
                ),
                trailing: DropdownButton<BoxFit>(
                  value: settingsProvider.imageFitMode,
                  onChanged: (BoxFit? newFit) {
                    if (newFit != null) {
                      settingsProvider.setImageFitMode(newFit);
                    }
                  },
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(value: BoxFit.cover, child: Text('Cover')),
                    DropdownMenuItem(value: BoxFit.contain, child: Text('Fit')),
                    DropdownMenuItem(value: BoxFit.fill, child: Text('Fill')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadSettingsSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return _buildSettingsCard(
          context,
          Column(
            children: [
              // Download Method
              ListTile(
                leading: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                title: const Text(
                  'Download Engine',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('High-speed secure fetching'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'OPTIMIZED',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                onTap: () => _showDownloadMethodInfo(context),
              ),

              const Divider(height: 1, indent: 56),

              // Browser Info
              ListTile(
                leading: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
                title: const Text(
                  'External Handlers',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Chrome Tabs / Safari Support'),
                trailing: const Icon(Icons.info_outline_rounded, size: 18),
                onTap: () => _showBrowserInfo(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadMethodInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Method'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎯 Smart Download Strategy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Direct Download Links
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.download, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Direct Download Links',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'URLs with:\n• ?f=filename.mp4\n• download= parameter\n• /data/ path\n• .mp4?, .zip?, .rar?',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '→ External Browser (Recommended)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Regular URLs
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.web, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Regular URLs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Streaming URLs, web pages, etc.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '→ In-App WebView (First Try)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Why this approach
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Why This Approach?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• External browsers handle direct downloads better\n'
                      '• In-app WebView has limited file download capabilities\n'
                      '• Coomer/Kemono servers prefer browser clients\n'
                      '• Automatic fallback ensures reliability',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showBrowserInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.browser_updated, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Browser Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌐 Browser Compatibility',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Platform:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('• Android: Chrome Custom Tabs'),
            Text('• iOS: SFSafariViewController'),
            const SizedBox(height: 12),
            const Text(
              'Keuntungan:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('• Server melihat sebagai browser asli'),
            const Text('• Cookie dan TLS browser'),
            const Text('• Tidak ada tab permanen'),
            const Text('• Auto-close otomatis'),
            const Text('• UX tetap di dalam aplikasi'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '📱 Solusi terbaik untuk download stabil',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataStorageSection() {
    return Consumer2<SettingsProvider, DataUsageTracker>(
      builder: (context, settingsProvider, dataUsageTracker, child) {
        return _buildSettingsCard(
          context,
          Column(
            children: [
              // Data Usage Monitor
              ListTile(
                leading: const Icon(
                  Icons.analytics_rounded,
                  size: 20,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  'Data Usage Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${dataUsageTracker.getUsageInMB(dataUsageTracker.sessionUsage).toStringAsFixed(2)} MB in current session',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DataUsageDashboard(),
                    ),
                  );
                },
              ),

              const Divider(height: 1, indent: 56),

              // Cache Size Info
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services_rounded,
                  size: 20,
                  color: Colors.amber,
                ),
                title: const Text(
                  'Disk Cache',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: FutureBuilder<String>(
                  future: _cacheSizeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Calculating usage...');
                    }
                    return Text('${snapshot.data ?? '0 B'} currently stored');
                  },
                ),
                trailing: TextButton(
                  onPressed: () => _clearCache(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('CLEAR'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutSection() {
    return _buildSettingsCard(
      context,
      Column(
        children: [
          // Version
          const ListTile(
            leading: Icon(
              Icons.verified_rounded,
              size: 20,
              color: Colors.greenAccent,
            ),
            title: Text(
              'Build Version',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('1.0.3-premium'),
          ),

          const Divider(height: 1, indent: 56),

          // Data Source
          const ListTile(
            leading: Icon(
              Icons.cloud_sync_rounded,
              size: 20,
              color: Colors.blueAccent,
            ),
            title: Text(
              'Data Sources',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Kemono & Coomer Decentralized API'),
          ),

          const Divider(height: 1, indent: 56),

          // Credits: Official API
          ListTile(
            leading: const Icon(
              Icons.auto_stories_rounded,
              size: 20,
              color: Colors.orangeAccent,
            ),
            title: const Text(
              'API Documentation',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('kemono.cr/documentation'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 14),
            onTap: () => _openLink('https://kemono.cr/documentation/api'),
          ),

          const Divider(height: 1, indent: 56),

          // Credits: Search by Name API
          ListTile(
            leading: const Icon(
              Icons.code_rounded,
              size: 20,
              color: Colors.cyanAccent,
            ),
            title: const Text(
              'Core Engine',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Powered by mbahArip API'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 14),
            onTap: () => _openLink('https://github.com/mbahArip/kemono-api'),
          ),

          const Divider(height: 1, indent: 56),

          // Disclaimer
          const ListTile(
            leading: Icon(
              Icons.gavel_rounded,
              size: 20,
              color: Colors.blueGrey,
            ),
            title: Text(
              'Legal Disclaimer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Educational viewer & proxy gateway'),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  String _getThemeDisplayName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _getTextSizeDisplayName(double textScale) {
    if (textScale <= 0.9) return 'Small';
    if (textScale >= 1.1) return 'Large';
    return 'Normal';
  }

  String _getServiceDisplayName(ApiSource source) {
    return source.name.toUpperCase();
  }

  String _getImageFitDisplayName(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'Cover';
      case BoxFit.contain:
        return 'Fit';
      case BoxFit.fill:
        return 'Fill';
      default:
        return 'Cover';
    }
  }

  String _getPostCardStyleDisplayName(String style) {
    switch (style) {
      case 'compact':
        return 'Compact';
      case 'rich':
      default:
        return 'Rich';
    }
  }

  void _showBlockedTagsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BlockedTagsScreen()),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performClearCache();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open link')));
  }

  Future<void> _performClearCache() async {
    await customCacheManager.emptyCache();
    await coomerCacheManager.emptyCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (!mounted) return;
    setState(() {
      _cacheSizeFuture = _calculateCacheSize();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }
}

/// Blocked Tags Screen
class BlockedTagsScreen extends StatefulWidget {
  const BlockedTagsScreen({super.key});

  @override
  State<BlockedTagsScreen> createState() => _BlockedTagsScreenState();
}

class _BlockedTagsScreenState extends State<BlockedTagsScreen> {
  final TextEditingController _tagController = TextEditingController();
  List<String> _blockedTags = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedTags();
  }

  void _loadBlockedTags() {
    final tagFilterProvider = Provider.of<TagFilterProvider>(
      context,
      listen: false,
    );
    setState(() {
      _blockedTags = List.from(tagFilterProvider.blacklist);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Blocked Tags'),
        backgroundColor: AppTheme.getSurfaceColor(context),
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Add Tag Input
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter tag to block...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) => _addTag(value),
                  ),
                ),
                IconButton(
                  onPressed: () => _addTag(_tagController.text),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // Blocked Tags List
          Expanded(
            child: _blockedTags.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block_outlined,
                          size: 64,
                          color: AppTheme.getOnSurfaceColor(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No blocked tags',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.getOnSurfaceColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add tags to filter content',
                          style: AppTheme.captionStyle.copyWith(
                            color: AppTheme.getOnSurfaceColor(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _blockedTags.length,
                    itemBuilder: (context, index) {
                      final tag = _blockedTags[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ListTile(
                          title: Text(tag),
                          trailing: IconButton(
                            onPressed: () => _removeTag(tag),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addTag(String tag) {
    if (tag.trim().isEmpty) return;

    final normalizedTag = tag.trim().toLowerCase();
    if (_blockedTags.contains(normalizedTag)) return;

    final tagFilterProvider = Provider.of<TagFilterProvider>(
      context,
      listen: false,
    );
    tagFilterProvider.addToBlacklist(normalizedTag);

    setState(() {
      _blockedTags.add(normalizedTag);
      _tagController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Blocked: $normalizedTag')));
  }

  void _removeTag(String tag) {
    final tagFilterProvider = Provider.of<TagFilterProvider>(
      context,
      listen: false,
    );
    tagFilterProvider.removeFromBlacklist(tag);

    setState(() {
      _blockedTags.remove(tag);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unblocked: $tag')));
  }
}

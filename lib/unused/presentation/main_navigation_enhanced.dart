import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/persistent_tab_view.dart';
import '../widgets/enhanced_media_grid.dart';
import 'home_ux_screen.dart';
import 'search_screen_new.dart';
import 'enhanced_bookmark_screen.dart';
import 'enhanced_history_screen.dart';
import 'settings_screen.dart';

/// Enhanced Main Navigation dengan persistent tabs & state management
/// 
/// Features:
/// - Persistent tab state preservation
/// - Enhanced bookmark & history screens
/// - Better navigation experience
/// - Memory optimization
class MainNavigationEnhanced extends StatefulWidget {
  const MainNavigationEnhanced({super.key});

  @override
  State<MainNavigationEnhanced> createState() => _MainNavigationEnhancedState();
}

class _MainNavigationEnhancedState extends State<MainNavigationEnhanced> {
  late TabController _tabController;
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [];
  final List<int> _tabIndices = [0, 1, 2, 3]; // Home, Search, Bookmarks, Settings

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: Navigator.of(context));
    
    // Create navigator keys for each tab
    for (int i = 0; i < 4; i++) {
      _navigatorKeys.add(GlobalKey<NavigatorState>());
    }
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: WillPopScope(
        onWillPop: _onWillPop,
        child: PersistentTabView(
          tabs: [
            TabData(
              label: 'Home',
              icon: Icons.home,
              builder: () => _buildTabNavigator(0),
            ),
            TabData(
              label: 'Search',
              icon: Icons.search,
              builder: () => _buildTabNavigator(1),
            ),
            TabData(
              label: 'Bookmarks',
              icon: Icons.bookmark,
              badge: _getBookmarkCount() > 0 ? _getBookmarkCount().toString() : null,
              builder: () => _buildTabNavigator(2),
            ),
            TabData(
              label: 'Settings',
              icon: Icons.settings,
              builder: () => _buildTabNavigator(3),
            ),
          ],
          controller: _tabController,
          enableLazyLoading: true,
          preserveState: true,
          onTap: (index) {
            HapticFeedback.lightImpact();
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTabNavigator(int tabIndex) {
    return Navigator(
      key: _navigatorKeys[tabIndex],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => _getTabContent(tabIndex),
          settings: settings,
        );
      },
    );
  }

  Widget _getTabContent(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return const HomeUXScreen();
      case 1:
        return const SearchScreenNew();
      case 2:
        return const EnhancedBookmarkScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const HomeUXScreen();
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.home, 'Home'),
              _buildBottomNavItem(1, Icons.search, 'Search'),
              _buildBottomNavItem(2, Icons.bookmark, 'Bookmarks', hasBadge: true),
              _buildBottomNavItem(3, Icons.settings, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label, {bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
    final badgeCount = hasBadge ? _getBadgeCount(index) : 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _tabController.animateTo(index);
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected 
                      ? AppTheme.primaryColor 
                      : AppTheme.secondaryTextColor,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTheme.captionStyle.copyWith(
                    color: isSelected 
                        ? AppTheme.primaryColor 
                        : AppTheme.secondaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            
            // Badge indicator
            if (badgeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getBadgeCount(int index) {
    switch (index) {
      case 2: // Bookmarks
        return _getBookmarkCount();
      default:
        return 0;
    }
  }

  int _getBookmarkCount() {
    // TODO: Get actual bookmark count from BookmarkManager
    // For now, return a mock count
    return 0;
  }

  Future<bool> _onWillPop() async {
    final currentNavigator = _navigatorKeys[_currentIndex].currentState;
    
    if (currentNavigator?.canPop() == true) {
      currentNavigator?.pop();
      return false;
    }
    
    // If current tab is not home, switch to home
    if (_currentIndex != 0) {
      _tabController.animateTo(0);
      setState(() {
        _currentIndex = 0;
      });
      return false;
    }
    
    // If on home tab, show exit confirmation
    return await _showExitConfirmation();
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Exit App?',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        content: Text(
          'Are you sure you want to exit the app?',
          style: AppTheme.bodyStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Exit',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    ) ?? false;
  }
}

/// Enhanced Tab View dengan proper navigation stack management
class EnhancedTabView extends StatefulWidget {
  final Widget child;
  final int tabIndex;
  final GlobalKey<NavigatorState>? navigatorKey;

  const EnhancedTabView({
    super.key,
    required this.child,
    required this.tabIndex,
    this.navigatorKey,
  });

  @override
  State<EnhancedTabView> createState() => _EnhancedTabViewState();
}

class _EnhancedTabViewState extends State<EnhancedTabView> {
  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => widget.child,
          settings: settings,
        );
      },
    );
  }
}

/// Tab Data untuk Enhanced Navigation
class EnhancedTabData {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  final String? badge;
  final bool isDisabled;

  EnhancedTabData({
    required this.label,
    required this.icon,
    required this.builder,
    this.badge,
    this.isDisabled = false,
  });
}

/// Enhanced Bottom Navigation dengan badge support
class EnhancedBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<EnhancedTabData> tabs;

  const EnhancedBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              return _buildBottomNavItem(index, tab);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, EnhancedTabData tab) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: tab.isDisabled ? null : () {
        HapticFeedback.lightImpact();
        onTap(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab.icon,
                  size: 24,
                  color: tab.isDisabled
                      ? AppTheme.secondaryTextColor.withOpacity(0.5)
                      : isSelected 
                          ? AppTheme.primaryColor 
                          : AppTheme.secondaryTextColor,
                ),
                const SizedBox(height: 4),
                Text(
                  tab.label,
                  style: AppTheme.captionStyle.copyWith(
                    color: tab.isDisabled
                        ? AppTheme.secondaryTextColor.withOpacity(0.5)
                        : isSelected 
                            ? AppTheme.primaryColor 
                            : AppTheme.secondaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            
            // Badge indicator
            if (tab.badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    tab.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced Settings Screen dengan proper navigation
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        children: [
          // App Info Section
          Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.mdRadius),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: AppTheme.primaryColor),
                  title: Text('About'),
                  subtitle: Text('App version and information'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showAboutDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.privacy_tip, color: AppTheme.primaryColor),
                  title: Text('Privacy Policy'),
                  subtitle: Text('How we handle your data'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showPrivacyPolicy();
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.mdSpacing),
          
          // Cache Management Section
          Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.mdRadius),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.storage, color: AppTheme.primaryColor),
                  title: Text('Cache Management'),
                  subtitle: Text('Clear cached data'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showCacheDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.history, color: AppTheme.primaryColor),
                  title: Text('Clear History'),
                  subtitle: Text('Remove browsing history'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showHistoryDialog();
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.mdSpacing),
          
          // Preferences Section
          Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.mdRadius),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.video_settings, color: AppTheme.primaryColor),
                  title: Text('Video Quality'),
                  subtitle: Text('Default video playback quality'),
                  trailing: Text('Auto'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showVideoQualityDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.image, color: AppTheme.primaryColor),
                  title: Text('Image Quality'),
                  subtitle: Text('Default image loading quality'),
                  trailing: Text('High'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showImageQualityDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.play_circle_outline, color: AppTheme.primaryColor),
                  title: Text('Auto-play Videos'),
                  subtitle: Text('Automatically play videos'),
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'About',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kemono/Coomer Viewer',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text(
              'Version: 1.0.0',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text(
              'A modern Flutter app for browsing Kemono and Coomer content with enhanced UX features.',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Privacy Policy',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'This app does not collect any personal data. All data is stored locally on your device.\n\n'
            'Cached images and videos are stored temporarily for performance and can be cleared at any time.\n\n'
            'Your browsing history is also stored locally and can be cleared through the settings.',
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Cache Management',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_sweep, color: AppTheme.errorColor),
              title: Text('Clear Image Cache'),
              subtitle: Text('Remove cached images'),
              onTap: () {
                Navigator.of(context).pop();
                _clearImageCache();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep, color: AppTheme.errorColor),
              title: Text('Clear Video Cache'),
              subtitle: Text('Remove cached videos'),
              onTap: () {
                Navigator.of(context).pop();
                _clearVideoCache();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep, color: AppTheme.errorColor),
              title: Text('Clear All Cache'),
              subtitle: Text('Remove all cached data'),
              onTap: () {
                Navigator.of(context).pop();
                _clearAllCache();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Clear History',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        content: Text(
          'Are you sure you want to clear your browsing history? This action cannot be undone.',
          style: AppTheme.bodyStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearHistory();
            },
            child: Text(
              'Clear',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showVideoQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Video Quality',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'Auto', 'Low', 'Medium', 'High', 'Original'
          ].map((quality) => ListTile(
            title: Text(quality),
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Set video quality preference
            },
          )).toList(),
        ],
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showImageQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Image Quality',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'Low', 'Medium', 'High', 'Original'
          ].map((quality) => ListTile(
            title: Text(quality),
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Set image quality preference
            },
          )).toList(),
        ],
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _clearImageCache() {
    // TODO: Implement image cache clearing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image cache cleared'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _clearVideoCache() {
    // TODO: Implement video cache clearing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video cache cleared'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _clearAllCache() {
    // TODO: Implement all cache clearing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All cache cleared'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _clearHistory() {
    // TODO: Implement history clearing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('History cleared'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}

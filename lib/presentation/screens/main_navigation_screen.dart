import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

// Screens
import 'latest_posts_screen.dart';
import 'search_screen_dual.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'discord_server_screen.dart';

// Theme
import '../theme/app_theme.dart';

/// MainNavigationScreen — Social Media Style Bottom Nav
///
/// Features:
/// - Floating glass pill navigation bar
/// - Gradient selected indicator
/// - Smooth scale + fade animations
/// - Haptic feedback
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  late List<AnimationController> _animControllers;
  late List<Animation<double>> _scaleAnims;

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.home_rounded,
      label: 'Home',
      color: AppTheme.primaryColor,
    ),
    _NavItem(
      icon: Icons.search_rounded,
      label: 'Search',
      color: AppTheme.secondaryAccent,
    ),
    _NavItem(
      icon: Icons.forum_rounded,
      label: 'Discord',
      color: Color(0xFF5865F2),
    ),
    _NavItem(
      icon: Icons.bookmark_rounded,
      label: 'Saved',
      color: Color(0xFFFFD740),
    ),
    _NavItem(
      icon: Icons.settings_rounded,
      label: 'Settings',
      color: Color(0xFF00B0FF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animControllers = List.generate(_navItems.length, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 220),
        vsync: this,
      );
    });
    _scaleAnims = _animControllers.map((c) {
      return Tween<double>(
        begin: 1.0,
        end: 1.07,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }).toList();
    _animControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _animControllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    _animControllers[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _animControllers[index].forward();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          if (i != _currentIndex) {
            _animControllers[_currentIndex].reverse();
            setState(() => _currentIndex = i);
            _animControllers[i].forward();
          }
        },
        children: [
          const LatestPostsScreen(),
          const SearchScreenDual(),
          const DiscordServerScreen(),
          SavedScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(isDark),
    );
  }

  Widget _buildNavBar(bool isDark) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemSlotWidth =
                (constraints.maxWidth - 12) / _navItems.length;
            final indicatorWidth = (itemSlotWidth - 18)
                .clamp(26.0, 56.0)
                .toDouble();
            final currentColor = _navItems[_currentIndex].color;

            return ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1B1F32).withValues(alpha: 0.92),
                              const Color(0xFF101424).withValues(alpha: 0.94),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.92),
                              const Color(0xFFF2F6FF).withValues(alpha: 0.94),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.12,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 28,
                        spreadRadius: -10,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        top: 8,
                        left:
                            6 +
                            (_currentIndex * itemSlotWidth) +
                            ((itemSlotWidth - indicatorWidth) / 2),
                        child: Container(
                          width: indicatorWidth,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: LinearGradient(
                              colors: [
                                currentColor.withValues(alpha: 0.55),
                                currentColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: currentColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        child: Row(
                          children: _navItems.asMap().entries.map((e) {
                            final i = e.key;
                            final item = e.value;
                            final selected = i == _currentIndex;
                            return Expanded(
                              child: _buildNavItem(item, i, selected, isDark),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool selected, bool isDark) {
    final inactiveColor = isDark
        ? AppTheme.darkSecondaryTextColor
        : AppTheme.lightSecondaryTextColor;

    return ScaleTransition(
      scale: _scaleAnims[index],
      child: InkWell(
        onTap: () => _onTap(index),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 38 : 34,
                height: selected ? 38 : 34,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            item.color.withValues(alpha: 0.34),
                            item.color.withValues(alpha: 0.16),
                          ],
                        )
                      : null,
                  color: selected
                      ? null
                      : (isDark
                            ? AppTheme.darkCardColor.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.65)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? item.color.withValues(alpha: 0.68)
                        : (isDark
                              ? AppTheme.darkBorderColor.withValues(alpha: 0.7)
                              : AppTheme.lightBorderColor.withValues(
                                  alpha: 0.8,
                                )),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.32),
                            blurRadius: 14,
                            spreadRadius: -6,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.icon,
                  color: selected ? item.color : inactiveColor,
                  size: selected ? 21 : 19,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: selected
                      ? item.color.withValues(alpha: 0.95)
                      : inactiveColor.withValues(alpha: 0.72),
                  fontSize: selected ? 11.5 : 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// Navigation Item Model (kept for compat)
class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

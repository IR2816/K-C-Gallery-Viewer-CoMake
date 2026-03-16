import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Persistent Tab View dengan state preservation & lazy loading
///
/// Features:
/// - State preservation antar tab switches
/// - Lazy loading untuk tab content
/// - Memory management untuk tab states
/// - Smooth transitions dengan skeleton loading
class PersistentTabView extends StatefulWidget {
  final List<TabData> tabs;
  final TabController? controller;
  final bool enableLazyLoading;
  final bool preserveState;
  final ValueChanged<int>? onTap;
  final Color? backgroundColor;
  final double? height;

  const PersistentTabView({
    super.key,
    required this.tabs,
    this.controller,
    this.enableLazyLoading = true,
    this.preserveState = true,
    this.onTap,
    this.backgroundColor,
    this.height,
  });

  @override
  State<PersistentTabView> createState() => _PersistentTabViewState();
}

class _PersistentTabViewState extends State<PersistentTabView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, Widget> _tabWidgets = {};
  final Map<int, GlobalKey> _tabKeys = {};
  final Map<int, bool> _tabLoaded = {};
  bool _isLoading = false;
  int _previousIndex = 0;

  @override
  bool get wantKeepAlive => widget.preserveState;

  @override
  void initState() {
    super.initState();
    _tabController =
        widget.controller ??
        TabController(length: widget.tabs.length, vsync: this);

    _tabController.addListener(_handleTabChange);
    _initializeTabs();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    if (widget.controller == null) {
      _tabController.dispose();
    }
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }

    final currentIndex = _tabController.index;
    if (currentIndex != _previousIndex) {
      _previousIndex = currentIndex;
      widget.onTap?.call(currentIndex);
      _loadTabIfNeeded(currentIndex);
    }
  }

  void _initializeTabs() {
    for (int i = 0; i < widget.tabs.length; i++) {
      _tabKeys[i] = GlobalKey();
      _tabLoaded[i] = false;

      if (widget.enableLazyLoading) {
        // Only create first tab initially
        if (i == 0) {
          _tabWidgets[i] = _createTabWidget(i);
          _tabLoaded[i] = true;
        }
      } else {
        // Create all tabs immediately
        _tabWidgets[i] = _createTabWidget(i);
        _tabLoaded[i] = true;
      }
    }
  }

  Widget _createTabWidget(int index) {
    final tabData = widget.tabs[index];

    if (widget.preserveState) {
      return KeyedSubtree(
        key: ValueKey('tab_$index'),
        child: _TabWrapper(
          key: _tabKeys[index],
          tabIndex: index,
          onDispose: () {
            _tabLoaded[index] = false;
          },
          child: tabData.builder(),
        ),
      );
    } else {
      return KeyedSubtree(
        key: ValueKey('tab_$index'),
        child: tabData.builder(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final containerHeight = widget.height;

    return Container(
      height: containerHeight,
      color: widget.backgroundColor ?? AppTheme.backgroundColor,
      child: Column(
        children: [
          // Tab Bar
          _buildTabBar(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(widget.tabs.length, (index) {
                if (widget.enableLazyLoading &&
                    !_tabLoaded.containsKey(index)) {
                  return _buildTabSkeleton();
                }

                return _tabWidgets[index] ?? _buildTabSkeleton();
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.cardColor)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryColor,
        labelColor: AppTheme.primaryTextColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        labelStyle: AppTheme.captionStyle.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTheme.captionStyle,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: widget.tabs
            .map(
              (tab) => Tab(
                text: tab.label,
                icon: tab.icon != null ? Icon(tab.icon, size: 20) : null,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTabSkeleton() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        children: [
          // Header skeleton
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Content skeleton
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: AppTheme.smSpacing),
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.smRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadTabIfNeeded(int index) {
    if (widget.enableLazyLoading && (!_tabLoaded[index] ?? false)) {
      setState(() {
        _isLoading = true;
      });

      // Simulate loading delay untuk smooth transition
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _tabWidgets[index] = _createTabWidget(index);
            _tabLoaded[index] = true;
            _isLoading = false;
          });
        }
      });
    }
  }
}

/// Tab wrapper untuk state management
class _TabWrapper extends StatefulWidget {
  final Widget child;
  final int tabIndex;
  final VoidCallback? onDispose;

  const _TabWrapper({
    super.key,
    required this.child,
    required this.tabIndex,
    this.onDispose,
  });

  @override
  State<_TabWrapper> createState() => _TabWrapperState();
}

class _TabWrapperState extends State<_TabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }
}

class TabData {
  final String label;
  final IconData? icon;
  final Widget Function() builder;
  final String? badge;
  final bool isDisabled;

  TabData({
    required this.label,
    this.icon,
    required this.builder,
    this.badge,
    this.isDisabled = false,
  });
}

/// Enhanced Tab Bar dengan badge support
class EnhancedTabBar extends StatelessWidget {
  final List<TabData> tabs;
  final TabController controller;
  final ValueChanged<int>? onTap;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;

  const EnhancedTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.onTap,
    this.backgroundColor,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.cardColor)),
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: indicatorColor ?? AppTheme.primaryColor,
        labelColor: labelColor ?? AppTheme.primaryTextColor,
        unselectedLabelColor:
            unselectedLabelColor ?? AppTheme.secondaryTextColor,
        labelStyle: AppTheme.captionStyle.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTheme.captionStyle,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.tab,
        onTap: onTap,
        tabs: tabs.map((tab) => _buildTab(tab)).toList(),
      ),
    );
  }

  Widget _buildTab(TabData tab) {
    return Tab(
      child: Stack(
        children: [
          // Tab content
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.icon != null) ...[
                Icon(tab.icon, size: 20),
                const SizedBox(width: AppTheme.xsSpacing),
              ],
              Text(tab.label),
            ],
          ),

          // Badge
          if (tab.badge != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
    );
  }
}

/// Tab View dengan swipe gesture support
class SwipeableTabView extends StatefulWidget {
  final List<TabData> tabs;
  final TabController? controller;
  final bool enableSwipe;
  final bool enableLazyLoading;
  final bool preserveState;
  final ValueChanged<int>? onTap;

  const SwipeableTabView({
    super.key,
    required this.tabs,
    this.controller,
    this.enableSwipe = true,
    this.enableLazyLoading = true,
    this.preserveState = true,
    this.onTap,
  });

  @override
  State<SwipeableTabView> createState() => _SwipeableTabViewState();
}

class _SwipeableTabViewState extends State<SwipeableTabView> {
  late TabController _tabController;
  final Map<int, Widget> _tabWidgets = {};
  final Map<int, bool> _tabLoaded = {};

  @override
  void initState() {
    super.initState();
    _tabController =
        widget.controller ??
        TabController(length: widget.tabs.length, vsync: Navigator.of(context));
    _initializeTabs();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _tabController.dispose();
    }
    super.dispose();
  }

  void _initializeTabs() {
    for (int i = 0; i < widget.tabs.length; i++) {
      _tabLoaded[i] = false;

      if (widget.enableLazyLoading) {
        if (i == 0) {
          _tabWidgets[i] = widget.tabs[i].builder();
          _tabLoaded[i] = true;
        }
      } else {
        _tabWidgets[i] = widget.tabs[i].builder();
        _tabLoaded[i] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        EnhancedTabBar(
          tabs: widget.tabs,
          controller: _tabController,
          onTap: (index) {
            widget.onTap?.call(index);
            _loadTabIfNeeded(index);
          },
        ),

        // Tab Content
        Expanded(
          child: widget.enableSwipe
              ? PageView.builder(
                  controller: PageController(initialPage: _tabController.index),
                  onPageChanged: (index) {
                    _tabController.animateTo(index);
                    widget.onTap?.call(index);
                    _loadTabIfNeeded(index);
                  },
                  itemCount: widget.tabs.length,
                  itemBuilder: (context, index) {
                    if (widget.enableLazyLoading && !_tabLoaded[index]!) {
                      return _buildTabSkeleton();
                    }

                    return _tabWidgets[index] ?? _buildTabSkeleton();
                  },
                )
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(widget.tabs.length, (index) {
                    if (widget.enableLazyLoading && !_tabLoaded[index]!) {
                      return _buildTabSkeleton();
                    }

                    return _tabWidgets[index] ?? _buildTabSkeleton();
                  }),
                ),
        ),
      ],
    );
  }

  Widget _buildTabSkeleton() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
          ),
          const SizedBox(height: AppTheme.mdSpacing),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: AppTheme.smSpacing),
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.smRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadTabIfNeeded(int index) {
    if (widget.enableLazyLoading && !_tabLoaded[index]!) {
      setState(() {
        _tabWidgets[index] = widget.tabs[index].builder();
        _tabLoaded[index] = true;
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/high_impact_features.dart';
import '../widgets/consistent_gesture_handler.dart';

/// Enhanced History Screen dengan filter & management
///
/// Features:
/// - Filter by type (posts, creators)
/// - Clear history dengan confirmation
/// - Quick access to recent items
/// - Privacy controls
class EnhancedHistoryScreen extends StatefulWidget {
  const EnhancedHistoryScreen({super.key});

  @override
  State<EnhancedHistoryScreen> createState() => _EnhancedHistoryScreenState();
}

class _EnhancedHistoryScreenState extends State<EnhancedHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<HistoryItem> _recentPosts = [];
  List<HistoryItem> _recentCreators = [];
  List<HistoryItem> _filteredPosts = [];
  List<HistoryItem> _filteredCreators = [];
  bool _isLoading = true;
  HistoryFilter _filter = HistoryFilter.all;
  DateTimeRange? _dateRange;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await HistoryManager.getRecentPosts(limit: 100);
      final creators = await HistoryManager.getRecentCreators(limit: 100);

      setState(() {
        _recentPosts = posts.map((post) => HistoryItem.fromPost(post)).toList();
        _recentCreators = creators
            .map((creator) => HistoryItem.fromCreator(creator))
            .toList();
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    // Apply search filter
    _filteredPosts = _recentPosts.where((item) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return item.title.toLowerCase().contains(query) ||
            item.subtitle.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    _filteredCreators = _recentCreators.where((item) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return item.title.toLowerCase().contains(query) ||
            item.subtitle.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    // Apply date filter
    if (_dateRange != null) {
      _filteredPosts = _filteredPosts.where((item) {
        return item.timestamp.isAfter(_dateRange!.start) &&
            item.timestamp.isBefore(_dateRange!.end);
      }).toList();

      _filteredCreators = _filteredCreators.where((item) {
        return item.timestamp.isAfter(_dateRange!.start) &&
            item.timestamp.isBefore(_dateRange!.end);
      }).toList();
    }

    // Apply type filter
    if (_filter != HistoryFilter.all) {
      switch (_filter) {
        case HistoryFilter.today:
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          _filteredPosts = _filteredPosts
              .where((item) => item.timestamp.isAfter(today))
              .toList();
          _filteredCreators = _filteredCreators
              .where((item) => item.timestamp.isAfter(today))
              .toList();
          break;
        case HistoryFilter.week:
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          _filteredPosts = _filteredPosts
              .where((item) => item.timestamp.isAfter(weekAgo))
              .toList();
          _filteredCreators = _filteredCreators
              .where((item) => item.timestamp.isAfter(weekAgo))
              .toList();
          break;
        case HistoryFilter.month:
          final monthAgo = DateTime.now().subtract(const Duration(days: 30));
          _filteredPosts = _filteredPosts
              .where((item) => item.timestamp.isAfter(monthAgo))
              .toList();
          _filteredCreators = _filteredCreators
              .where((item) => item.timestamp.isAfter(monthAgo))
              .toList();
          break;
        case HistoryFilter.all:
        default:
          // No filtering
          break;
      }
    }

    // Sort by timestamp (most recent first)
    _filteredPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _filteredCreators.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Search and filter section
          _buildSearchAndFilter(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPostsTab(), _buildCreatorsTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _isSearching ? 'Search History' : 'History',
        style: AppTheme.titleStyle.copyWith(color: AppTheme.primaryTextColor),
      ),
      backgroundColor: AppTheme.surfaceColor,
      foregroundColor: AppTheme.primaryTextColor,
      elevation: AppTheme.smElevation,
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.search, color: AppTheme.primaryTextColor),
            onPressed: _toggleSearch,
          ),
        if (_isSearching)
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.primaryTextColor),
            onPressed: _toggleSearch,
          ),
        PopupMenuButton<HistoryFilter>(
          icon: Icon(Icons.filter_list, color: AppTheme.primaryTextColor),
          onSelected: (filter) {
            setState(() {
              _filter = filter;
              _applyFilters();
            });
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: HistoryFilter.all,
              child: Row(
                children: [
                  Icon(Icons.history, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('All Time'),
                  if (_filter == HistoryFilter.all)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.smSpacing),
                      child: Icon(Icons.check, color: AppTheme.primaryColor),
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: HistoryFilter.today,
              child: Row(
                children: [
                  Icon(Icons.today, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('Today'),
                  if (_filter == HistoryFilter.today)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.smSpacing),
                      child: Icon(Icons.check, color: AppTheme.primaryColor),
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: HistoryFilter.week,
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('This Week'),
                  if (_filter == HistoryFilter.week)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.smSpacing),
                      child: Icon(Icons.check, color: AppTheme.primaryColor),
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: HistoryFilter.month,
              child: Row(
                children: [
                  Icon(Icons.calendar_month, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('This Month'),
                  if (_filter == HistoryFilter.month)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.smSpacing),
                      child: Icon(Icons.check, color: AppTheme.primaryColor),
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: HistoryFilter.custom,
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('Custom Range'),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryColor,
        labelColor: AppTheme.primaryTextColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        labelStyle: AppTheme.captionStyle.copyWith(fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            text: 'Posts',
            child: Stack(
              children: [
                const Text('Posts'),
                if (_filteredPosts.length != _recentPosts.length)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Tab(
            text: 'Creators',
            child: Stack(
              children: [
                const Text('Creators'),
                if (_filteredCreators.length != _recentCreators.length)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
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

  Widget _buildSearchAndFilter() {
    if (!_isSearching && _dateRange == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.cardColor)),
      ),
      child: Column(
        children: [
          if (_isSearching)
            TextField(
              autofocus: true,
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: 'Search history...',
                hintStyle: AppTheme.captionStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.mdRadius),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.secondaryTextColor,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.secondaryTextColor,
                        ),
                        onPressed: _clearSearch,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.mdPadding,
                  vertical: AppTheme.smPadding,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),

          if (_dateRange != null) ...[
            const SizedBox(height: AppTheme.smSpacing),
            Container(
              padding: const EdgeInsets.all(AppTheme.smPadding),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.smRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.smSpacing),
                  Expanded(
                    child: Text(
                      'Custom: ${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: AppTheme.secondaryTextColor,
                      size: 20,
                    ),
                    onPressed: _clearDateFilter,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (_filteredPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: _searchQuery.isNotEmpty || _dateRange != null
            ? 'No posts found'
            : 'No recently viewed posts',
        subtitle: _searchQuery.isNotEmpty || _dateRange != null
            ? 'Try different filters or search terms'
            : 'Posts you view will appear here',
        actionLabel: 'Browse Posts',
        onAction: _browsePosts,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      itemCount: _filteredPosts.length,
      itemBuilder: (context, index) => _buildHistoryItem(_filteredPosts[index]),
    );
  }

  Widget _buildCreatorsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (_filteredCreators.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: _searchQuery.isNotEmpty || _dateRange != null
            ? 'No creators found'
            : 'No recently viewed creators',
        subtitle: _searchQuery.isNotEmpty || _dateRange != null
            ? 'Try different filters or search terms'
            : 'Creators you view will appear here',
        actionLabel: 'Browse Creators',
        onAction: _browseCreators,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      itemCount: _filteredCreators.length,
      itemBuilder: (context, index) =>
          _buildHistoryItem(_filteredCreators[index]),
    );
  }

  Widget _buildHistoryItem(HistoryItem item) {
    return SwipeableCard(
      onSwipeRight: () => _navigateToItem(item),
      onSwipeLeft: () => _removeFromHistory(item),
      swipeRightColor: AppTheme.primaryColor,
      swipeLeftColor: AppTheme.errorColor,
      swipeRightIcon: Icon(Icons.open_in_new, color: Colors.white),
      swipeLeftIcon: Icon(Icons.clear, color: Colors.white),
      child: Card(
        color: AppTheme.surfaceColor,
        margin: const EdgeInsets.only(bottom: AppTheme.smSpacing),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.mdRadius),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppTheme.mdPadding),
          leading: CircleAvatar(
            backgroundImage: item.thumbnailUrl != null
                ? NetworkImage(item.thumbnailUrl!)
                : null,
            backgroundColor: AppTheme.cardColor,
            child: item.thumbnailUrl == null
                ? Text(
                    item.title.isNotEmpty ? item.title[0].toUpperCase() : '?',
                    style: AppTheme.bodyStyle.copyWith(
                      color: AppTheme.primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            item.title,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.xsSpacing),
              if (item.subtitle.isNotEmpty)
                Text(
                  item.subtitle,
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: AppTheme.xsSpacing),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.secondaryTextColor,
                  ),
                  const SizedBox(width: AppTheme.xsSpacing),
                  Text(
                    _formatRelativeTime(item.timestamp),
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.open_in_new, color: AppTheme.primaryColor),
                onPressed: () => _navigateToItem(item),
                tooltip: 'Open',
              ),
              IconButton(
                icon: Icon(Icons.clear, color: AppTheme.errorColor),
                onPressed: () => _removeFromHistory(item),
                tooltip: 'Remove from History',
              ),
            ],
          ),
          onTap: () => _navigateToItem(item),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.secondaryTextColor),
          const SizedBox(height: AppTheme.mdSpacing),
          Text(
            title,
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            subtitle,
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTheme.lgSpacing),
            ConsistentButton(
              text: actionLabel,
              icon: Icons.explore,
              type: ButtonType.primary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Filter button
        FloatingActionButton(
          heroTag: "filter",
          onPressed: _showFilterBottomSheet,
          backgroundColor: AppTheme.primaryColor,
          child: Icon(Icons.filter_list),
        ),

        const SizedBox(height: AppTheme.smSpacing),

        // Clear history button
        FloatingActionButton.extended(
          heroTag: "clear",
          onPressed: _showClearHistoryDialog,
          backgroundColor: AppTheme.errorColor,
          icon: Icon(Icons.delete_sweep),
          label: Text('Clear All'),
        ),
      ],
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _applyFilters();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _applyFilters();
    });
  }

  void _clearDateFilter() {
    setState(() {
      _dateRange = null;
      _applyFilters();
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.lgRadius),
          topRight: Radius.circular(AppTheme.lgRadius),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.filter_list, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.smSpacing),
                Text('Filter History', style: AppTheme.titleStyle),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.secondaryTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.mdSpacing),

            // Date range filter
            ListTile(
              leading: Icon(Icons.date_range, color: AppTheme.primaryColor),
              title: Text('Custom Date Range'),
              subtitle: _dateRange != null
                  ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                  : 'Select date range',
              trailing: _dateRange != null
                  ? Icon(Icons.clear, color: AppTheme.errorColor)
                  : null,
              onTap: _selectDateRange,
            ),

            const Divider(),

            // Quick filters
            ListTile(
              leading: Icon(Icons.today, color: AppTheme.primaryColor),
              title: Text('Today'),
              onTap: () {
                setState(() {
                  _filter = HistoryFilter.today;
                  _applyFilters();
                });
                Navigator.of(context).pop();
              },
            ),

            ListTile(
              leading: Icon(Icons.date_range, color: AppTheme.primaryColor),
              title: Text('This Week'),
              onTap: () {
                setState(() {
                  _filter = HistoryFilter.week;
                  _applyFilters();
                });
                Navigator.of(context).pop();
              },
            ),

            ListTile(
              leading: Icon(Icons.calendar_month, color: AppTheme.primaryColor),
              title: Text('This Month'),
              onTap: () {
                setState(() {
                  _filter = HistoryFilter.month;
                  _applyFilters();
                });
                Navigator.of(context).pop();
              },
            ),

            ListTile(
              leading: Icon(Icons.history, color: AppTheme.primaryColor),
              title: Text('All Time'),
              onTap: () {
                setState(() {
                  _filter = HistoryFilter.all;
                  _applyFilters();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
        _filter = HistoryFilter.custom;
        _applyFilters();
      });
      Navigator.of(context).pop();
    }
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Clear All History?',
          style: AppTheme.titleStyle.copyWith(color: AppTheme.primaryTextColor),
        ),
        content: Text(
          'This will remove all items from your history. This action cannot be undone.',
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
              _clearAllHistory();
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllHistory() async {
    HapticFeedback.heavyImpact();

    try {
      await HistoryManager.clearHistory();

      if (mounted) {
        setState(() {
          _recentPosts.clear();
          _recentCreators.clear();
          _filteredPosts.clear();
          _filteredCreators.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('History cleared successfully'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear history'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeFromHistory(HistoryItem item) async {
    HapticFeedback.lightImpact();

    try {
      // TODO: Implement individual item removal from HistoryManager
      // For now, just remove from local state

      if (mounted) {
        setState(() {
          if (item.type == HistoryType.post) {
            _recentPosts.remove(item);
            _filteredPosts.remove(item);
          } else {
            _recentCreators.remove(item);
            _filteredCreators.remove(item);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from history'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove from history'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
          ),
        );
      }
    }
  }

  void _navigateToItem(HistoryItem item) {
    HapticFeedback.lightImpact();

    // TODO: Navigate to appropriate screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${item.title}...'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _browsePosts() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _browseCreators() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return _formatDate(timestamp);
    }
  }
}

enum HistoryFilter { all, today, week, month, custom }

enum HistoryType { post, creator }

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final DateTime timestamp;
  final HistoryType type;
  final Map<String, dynamic>? metadata;

  HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
    required this.timestamp,
    required this.type,
    this.metadata,
  });

  factory HistoryItem.fromPost(Map<String, dynamic> post) {
    return HistoryItem(
      id: post['id'] ?? '',
      title: post['title'] ?? 'Untitled Post',
      subtitle: post['subtitle'] ?? '',
      thumbnailUrl: post['thumbnailUrl'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(post['viewedAt'] ?? 0),
      type: HistoryType.post,
      metadata: post['metadata'],
    );
  }

  factory HistoryItem.fromCreator(Map<String, dynamic> creator) {
    return HistoryItem(
      id: creator['id'] ?? '',
      title: creator['title'] ?? 'Unknown Creator',
      subtitle: creator['subtitle'] ?? '',
      thumbnailUrl: creator['thumbnailUrl'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(creator['viewedAt'] ?? 0),
      type: HistoryType.creator,
      metadata: creator['metadata'],
    );
  }
}

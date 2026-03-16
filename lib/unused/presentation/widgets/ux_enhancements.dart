import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Prinsip 11: Insight lanjutan - UX enhancements tanpa biaya
///
/// Fitur yang bisa bikin UX "kelas atas":
/// - Skeleton loader
/// - Scroll position memory
/// - Double-tap image zoom
/// - Long-press copy post link
/// - Swipe gestures
/// - Haptic feedback
class UXEnhancements {
  /// Skeleton loader dengan animasi yang smooth
  static Widget buildSkeletonLoader({
    required Widget child,
    bool isLoading = false,
  }) {
    return AnimatedSwitcher(
      duration: AppTheme.normalDuration,
      child: isLoading ? _buildSkeleton(child) : child,
    );
  }

  static Widget _buildSkeleton(Widget originalChild) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.mdRadius),
      ),
      child: _SkeletonPlaceholder(child: originalChild),
    );
  }

  /// Image viewer dengan zoom capabilities
  static Widget buildInteractiveImageViewer({
    required String imageUrl,
    required Widget placeholder,
    VoidCallback? onDoubleTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: () {
        // Single tap untuk fullscreen
        HapticFeedback.lightImpact();
      },
      onDoubleTap: () {
        onDoubleTap?.call();
        HapticFeedback.mediumImpact();
      },
      onLongPress: () {
        onLongPress?.call();
        HapticFeedback.heavyImpact();
      },
      child: InteractiveViewer(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => placeholder,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder();
          },
        ),
      ),
    );
  }

  /// Swipeable card dengan dismiss actions
  static Widget buildSwipeableCard({
    required Widget child,
    List<Widget>? dismissActions,
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
  }) {
    return Dismissible(
      key: UniqueKey(),
      direction: dismissActions != null
          ? DismissDirection.horizontal
          : DismissDirection.none,
      dismissThresholds: const DismissThresholds(horizontal: 0.3),
      onDismissed: (direction) {
        HapticFeedback.selectionClick();
        if (direction == DismissDirection.startToEnd) {
          onSwipeRight?.call();
        } else if (direction == DismissDirection.endToStart) {
          onSwipeLeft?.call();
        }
      },
      background: Container(
        color: onSwipeRight != null
            ? AppTheme.successColor
            : AppTheme.errorColor,
        child: Align(
          alignment: onSwipeRight != null
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: Icon(
              onSwipeRight != null ? Icons.favorite : Icons.delete,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ),
      ),
      child: child,
    );
  }

  /// Pull-to-refresh dengan custom indicator
  static Widget buildCustomRefreshIndicator({
    required Widget child,
    required Future<void> Function() onRefresh,
    String? message,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      displacement: 60,
      child: child,
    );
  }

  /// Infinite scroll dengan loading indicator
  static Widget buildInfiniteScroll({
    required ScrollController controller,
    required List<Widget> children,
    required bool isLoading,
    required bool hasReachedEnd,
    required VoidCallback onLoadMore,
    Widget? loadingIndicator,
    Widget? endIndicator,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo is ScrollUpdateNotification) {
          final metrics = scrollInfo.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 200) {
            if (!isLoading && !hasReachedEnd) {
              onLoadMore();
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        itemCount: children.length + (hasReachedEnd ? 0 : 1),
        itemBuilder: (context, index) {
          if (index == children.length) {
            if (hasReachedEnd) {
              return endIndicator ?? _buildEndIndicator();
            }
            return loadingIndicator ?? _buildLoadingIndicator();
          }
          return children[index];
        },
      ),
    );
  }

  /// Search bar dengan suggestions dan history
  static Widget buildSmartSearchBar({
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<String> suggestions,
    required List<String> history,
    required Function(String) onSubmitted,
    required Function(String) onChanged,
    String? hintText,
    bool showHistory = true,
  }) {
    return Column(
      children: [
        // Search input
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: AppTheme.bodyStyle,
          decoration: InputDecoration(
            hintText: hintText ?? 'Search...',
            hintStyle: AppTheme.captionStyle,
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.mdRadius),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.secondaryTextColor,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppTheme.secondaryTextColor,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                      HapticFeedback.lightImpact();
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.mdPadding,
              vertical: AppTheme.smPadding,
            ),
          ),
          onChanged: onChanged,
          onSubmitted: (value) {
            onSubmitted(value);
            HapticFeedback.selectionClick();
          },
        ),

        // Suggestions/History
        if (showHistory && (suggestions.isNotEmpty || history.isNotEmpty))
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: AppTheme.smSpacing),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppTheme.mdRadius),
                bottomRight: Radius.circular(AppTheme.mdRadius),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.smPadding),
              children: [
                if (suggestions.isNotEmpty) ...[
                  Text(
                    'Suggestions',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.smSpacing),
                  ...suggestions.map(
                    (suggestion) => _buildSuggestionItem(suggestion, () {
                      controller.text = suggestion;
                      onSubmitted(suggestion);
                      HapticFeedback.selectionClick();
                    }),
                  ),
                ],

                if (history.isNotEmpty) ...[
                  Text(
                    'Recent Searches',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.smSpacing),
                  ...history
                      .take(5)
                      .map(
                        (item) => _buildSuggestionItem(item, () {
                          controller.text = item;
                          onSubmitted(item);
                          HapticFeedback.selectionClick();
                        }),
                      ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Floating action button dengan animation
  static Widget buildAnimatedFAB({
    required VoidCallback onPressed,
    required IconData icon,
    String? tooltip,
    bool extended = false,
    String? label,
  }) {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      icon: Icon(icon),
      label: extended ? Text(label ?? '') : null,
      tooltip: tooltip,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: AppTheme.primaryTextColor,
      elevation: AppTheme.mdElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.lgRadius),
      ),
      extendedPadding: extended
          ? const EdgeInsets.symmetric(horizontal: AppTheme.mdPadding)
          : null,
    );
  }

  /// Bottom sheet dengan smooth animation
  static Future<T?> showCustomBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = false,
    double? height,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: height ?? MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTheme.lgRadius),
            topRight: Radius.circular(AppTheme.lgRadius),
          ),
        ),
        child: child,
      ),
    );
  }

  /// Copy to clipboard dengan feedback
  static void copyToClipboard(String text, {String? message}) {
    // TODO: Implement clipboard functionality
    HapticFeedback.selectionClick();
    // Show snackbar feedback
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message ?? 'Copied to clipboard'),
    //     backgroundColor: AppTheme.successColor,
    //   ),
    // ),
    // );
  }

  /// Share functionality dengan native share
  static void shareContent(String content, {String? subject}) {
    HapticFeedback.mediumImpact();
    // TODO: Implement share functionality
    // Share.share(content, subject: subject);
  }

  // Helper widgets
  static Widget _buildSuggestionItem(String text, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.history, size: 16),
      title: Text(
        text,
        style: AppTheme.bodyStyle,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  static Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              strokeWidth: 2,
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text('Loading more...', style: AppTheme.captionStyle),
          ],
        ),
      ),
    );
  }

  static Widget _buildEndIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.secondaryTextColor,
              size: 24,
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text("You've reached the end", style: AppTheme.captionStyle),
          ],
        ),
      ),
    );
  }

  static Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppTheme.surfaceColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.secondaryTextColor,
              ),
              strokeWidth: 2,
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text('Loading...', style: AppTheme.captionStyle),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder widget
class _SkeletonPlaceholder extends StatefulWidget {
  final Widget child;

  const _SkeletonPlaceholder({required this.child});

  @override
  State<_SkeletonPlaceholder> createState() => _SkeletonPlaceholderState();
}

class _SkeletonPlaceholderState extends State<_SkeletonPlaceholder>
    with SingleTickerProviderState {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

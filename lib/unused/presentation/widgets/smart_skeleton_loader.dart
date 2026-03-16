import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Prinsip 3.1: Loading state yang jujur
///
/// ❌ Jangan:
/// - White screen
/// - Spinner tanpa konteks
///
/// ✅ Lakukan:
/// - Skeleton sesuai bentuk konten
/// - Placeholder mirip post card asli
///
/// 📌 Otak user: "oh ini lagi dimuat", bukan "app rusak?"
class SmartSkeletonLoader extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final SkeletonType type;
  final int itemCount;
  final Duration duration;

  const SmartSkeletonLoader({
    super.key,
    required this.child,
    this.isLoading = false,
    this.type = SkeletonType.post,
    this.itemCount = 5,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<SmartSkeletonLoader> createState() => _SmartSkeletonLoaderState();
}

class _SmartSkeletonLoaderState extends State<SmartSkeletonLoader>
    with TickerProviderState {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isLoading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SmartSkeletonLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isLoading && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppTheme.normalDuration,
      child: widget.isLoading ? _buildSkeleton() : widget.child,
    );
  }

  Widget _buildSkeleton() {
    switch (widget.type) {
      case SkeletonType.post:
        return _buildPostSkeleton();
      case SkeletonType.creator:
        return _buildCreatorSkeleton();
      case SkeletonType.media:
        return _buildMediaSkeleton();
      case SkeletonType.avatar:
        return _buildAvatarSkeleton();
      case SkeletonType.detail:
        return _buildDetailSkeleton();
      case SkeletonType.search:
        return _buildSearchSkeleton();
    }
  }

  Widget _buildPostSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      itemCount: widget.itemCount,
      itemBuilder: (context, index) => _buildPostCardSkeleton(),
    );
  }

  Widget _buildPostCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.mdSpacing),
      child: Card(
        color: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.mdRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.mdPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Creator header skeleton
              Row(
                children: [
                  _buildShimmer(32, 32, BorderRadius.circular(16)),
                  const SizedBox(width: AppTheme.smSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmer(
                          120,
                          14,
                          BorderRadius.circular(AppTheme.xsRadius),
                        ),
                        const SizedBox(height: 4),
                        _buildShimmer(
                          60,
                          10,
                          BorderRadius.circular(AppTheme.xsRadius),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.smSpacing),

              // Title skeleton
              _buildShimmer(
                double.infinity,
                16,
                BorderRadius.circular(AppTheme.xsRadius),
              ),
              const SizedBox(height: AppTheme.smSpacing),

              // Media preview skeleton
              _buildShimmer(
                double.infinity,
                200,
                BorderRadius.circular(AppTheme.smRadius),
              ),
              const SizedBox(height: AppTheme.smSpacing),

              // Meta skeleton
              Row(
                children: [
                  _buildShimmer(
                    40,
                    12,
                    BorderRadius.circular(AppTheme.xsRadius),
                  ),
                  const SizedBox(width: AppTheme.smSpacing),
                  _buildShimmer(
                    60,
                    12,
                    BorderRadius.circular(AppTheme.xsRadius),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        children: [
          // Creator header skeleton
          Row(
            children: [
              _buildShimmer(80, 80, BorderRadius.circular(40)),
              const SizedBox(width: AppTheme.mdSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmer(
                      150,
                      20,
                      BorderRadius.circular(AppTheme.xsRadius),
                    ),
                    const SizedBox(height: AppTheme.smSpacing),
                    _buildShimmer(
                      100,
                      16,
                      BorderRadius.circular(AppTheme.xsRadius),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Stats skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatSkeleton('Posts', '---'),
              _buildStatSkeleton('Followers', '---'),
            ],
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Tabs skeleton
          Row(
            children: [
              Expanded(
                child: _buildShimmer(
                  double.infinity,
                  40,
                  BorderRadius.circular(AppTheme.smRadius),
                ),
              ),
              const SizedBox(width: AppTheme.smSpacing),
              Expanded(
                child: _buildShimmer(
                  double.infinity,
                  40,
                  BorderRadius.circular(AppTheme.smRadius),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Content skeleton
          ...List.generate(3, (index) => _buildPostCardSkeleton()),
        ],
      ),
    );
  }

  Widget _buildMediaSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: AppTheme.smSpacing,
        mainAxisSpacing: AppTheme.smSpacing,
      ),
      itemCount: widget.itemCount,
      itemBuilder: (context, index) => _buildMediaItemSkeleton(),
    );
  }

  Widget _buildMediaItemSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
      child: Stack(
        children: [
          _buildShimmer(
            double.infinity,
            double.infinity,
            BorderRadius.circular(AppTheme.smRadius),
          ),
          if (index % 3 == 0) // Simulate video indicator
            Positioned(
              top: AppTheme.smSpacing,
              right: AppTheme.smSpacing,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarSkeleton() {
    return Row(
      children: [
        _buildShimmer(40, 40, BorderRadius.circular(20)),
        const SizedBox(width: AppTheme.smSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShimmer(100, 14, BorderRadius.circular(AppTheme.xsRadius)),
              const SizedBox(height: 4),
              _buildShimmer(60, 10, BorderRadius.circular(AppTheme.xsRadius)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator header skeleton
          _buildAvatarSkeleton(),
          const SizedBox(height: AppTheme.mdSpacing),

          // Title skeleton
          _buildShimmer(
            double.infinity,
            24,
            BorderRadius.circular(AppTheme.xsRadius),
          ),
          const SizedBox(height: AppTheme.smSpacing),

          // Meta skeleton
          Row(
            children: [
              _buildShimmer(40, 12, BorderRadius.circular(AppTheme.xsRadius)),
              const SizedBox(width: AppTheme.smSpacing),
              _buildShimmer(60, 12, BorderRadius.circular(AppTheme.xsRadius)),
            ],
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Media skeleton
          _buildShimmer(
            double.infinity,
            300,
            BorderRadius.circular(AppTheme.smRadius),
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Content skeleton
          _buildShimmer(
            double.infinity,
            16,
            BorderRadius.circular(AppTheme.xsRadius),
          ),
          const SizedBox(height: AppTheme.smSpacing),
          _buildShimmer(
            double.infinity,
            16,
            BorderRadius.circular(AppTheme.xsRadius),
          ),
          const SizedBox(height: AppTheme.smSpacing),
          _buildShimmer(200, 16, BorderRadius.circular(AppTheme.xsRadius)),
        ],
      ),
    );
  }

  Widget _buildSearchSkeleton() {
    return Column(
      children: [
        // Search bar skeleton
        Container(
          margin: const EdgeInsets.all(AppTheme.mdPadding),
          child: _buildShimmer(
            double.infinity,
            48,
            BorderRadius.circular(AppTheme.mdRadius),
          ),
        ),

        // Quick filters skeleton
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.mdPadding),
          child: Row(
            children: List.generate(
              5,
              (index) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: AppTheme.smSpacing),
                  child: _buildShimmer(
                    double.infinity,
                    40,
                    BorderRadius.circular(AppTheme.smRadius),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Results skeleton
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppTheme.mdPadding),
            itemCount: widget.itemCount,
            itemBuilder: (context, index) => _buildAvatarSkeleton(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatSkeleton(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.primaryTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildShimmer(double width, double height, BorderRadius borderRadius) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.cardColor,
                AppTheme.cardColor.withOpacity(_animation.value),
                AppTheme.cardColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

enum SkeletonType { post, creator, media, avatar, detail, search }

/// Utility untuk memudahkan penggunaan
class SkeletonLoader {
  static Widget post({
    required Widget child,
    bool isLoading = false,
    int itemCount = 5,
  }) {
    return SmartSkeletonLoader(
      isLoading: isLoading,
      type: SkeletonType.post,
      itemCount: itemCount,
      child: child,
    );
  }

  static Widget creator({
    required Widget child,
    bool isLoading = false,
    int itemCount = 3,
  }) {
    return SmartSkeletonLoader(
      isLoading: isLoading,
      type: SkeletonType.creator,
      itemCount: itemCount,
      child: child,
    );
  }

  static Widget media({
    required Widget child,
    bool isLoading = false,
    int itemCount = 15,
  }) {
    return SmartSkeletonLoader(
      isLoading: isLoading,
      type: SkeletonType.media,
      itemCount: itemCount,
      child: child,
    );
  }

  static Widget avatar({required Widget child, bool isLoading = false}) {
    return SmartSkeletonLoader(
      isLoading: isLoading,
      type: SkeletonType.avatar,
      child: child,
    );
  }

  static Widget detail({required Widget child, bool isLoading = false}) {
    return SmartSkeletonLoader(
      isLoading: isLoading,
      type: SkeletonType.detail,
      child: child,
    );
  }

  static Widget search({
    required Widget child,
    bool isLoading = false,
    int itemCount = 10,
  }) {
    return SmartSkeletonLoader(
      isLoading: isLoading,
      type: SkeletonType.search,
      itemCount: itemCount,
      child: child,
    );
  }
}

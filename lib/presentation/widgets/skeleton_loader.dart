import 'package:flutter/material.dart';

/// A reusable skeleton loader widget with a sweeping shimmer animation.
/// Adapts automatically to the current theme (light/dark).
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final Widget? child;
  final EdgeInsetsGeometry? margin;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.child,
  });

  /// Factory constructor for circular skeletons (e.g. avatars)
  factory AppSkeleton.circle({
    required double size,
    EdgeInsetsGeometry? margin,
  }) {
    return AppSkeleton(
      width: size,
      height: size,
      shape: BoxShape.circle,
      margin: margin,
    );
  }

  /// Factory constructor for rounded rectangular skeletons (e.g. cards, text)
  factory AppSkeleton.rounded({
    double? width,
    double? height,
    double borderRadius = 8.0,
    EdgeInsetsGeometry? margin,
    Widget? child,
  }) {
    return AppSkeleton(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(borderRadius),
      margin: margin,
      child: child,
    );
  }

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor =
        isDark ? Colors.grey[600]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            decoration: BoxDecoration(
              color: baseColor,
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle
                  ? null
                  : (widget.borderRadius ?? BorderRadius.circular(8)),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double percent;

  const _SlidingGradientTransform(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0.0, 0.0);
  }
}

/// A skeleton loader mimicking a post card in the Masonry grid
class PostGridSkeleton extends StatelessWidget {
  const PostGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image placeholder (randomly sized for masonry effect in a list context, or fixed if we just want a box)
          AppSkeleton.rounded(
            height: 180, // Average height for an image
            borderRadius: 16,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar and Name row
                Row(
                  children: [
                    AppSkeleton.circle(size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeleton.rounded(height: 12, width: double.infinity),
                          const SizedBox(height: 4),
                          AppSkeleton.rounded(height: 10, width: 60),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title/Content lines
                AppSkeleton.rounded(height: 14, width: double.infinity),
                const SizedBox(height: 6),
                AppSkeleton.rounded(height: 14, width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loader mimicking a popular creator card
class PopularCreatorSkeleton extends StatelessWidget {
  const PopularCreatorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Stack(
        children: [
          AppSkeleton.rounded(height: 118, borderRadius: 20),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                AppSkeleton.circle(size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSkeleton.rounded(height: 14, width: 120),
                      const SizedBox(height: 4),
                      AppSkeleton.rounded(height: 11, width: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Details page skeleton
class DetailScreenSkeleton extends StatelessWidget {
  const DetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App bar area
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppSkeleton.circle(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton.rounded(height: 16, width: 150),
                    const SizedBox(height: 6),
                    AppSkeleton.rounded(height: 12, width: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Media area
        AppSkeleton.rounded(
          height: 300,
          borderRadius: 0,
        ),
        // Action bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppSkeleton.circle(size: 32),
              const SizedBox(width: 16),
              AppSkeleton.circle(size: 32),
              const SizedBox(width: 16),
              AppSkeleton.circle(size: 32),
            ],
          ),
        ),
        // Content area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.rounded(height: 20, width: 250),
              const SizedBox(height: 16),
              AppSkeleton.rounded(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              AppSkeleton.rounded(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              AppSkeleton.rounded(height: 14, width: 200),
            ],
          ),
        ),
      ],
    );
  }
}

/// A skeleton loader mimicking a Discord chat message
class DiscordMessageSkeleton extends StatelessWidget {
  const DiscordMessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton.circle(size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppSkeleton.rounded(height: 14, width: 100),
                    const SizedBox(width: 8),
                    AppSkeleton.rounded(height: 10, width: 60),
                  ],
                ),
                const SizedBox(height: 8),
                AppSkeleton.rounded(height: 12, width: double.infinity),
                const SizedBox(height: 4),
                AppSkeleton.rounded(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

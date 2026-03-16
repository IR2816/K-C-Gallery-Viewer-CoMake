import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Prinsip 6: Konsistensi kecil yang bikin nyaman
///
/// 6.1 Gesture konsisten
/// - Tap card → detail
/// - Swipe down → dismiss
/// - Back selalu ke state sebelumnya
///
/// Jangan:
/// - Satu halaman swipe, yang lain tidak
///
/// 6.2 Icon & label jelas
/// - Jangan ikon tanpa teks
/// - Jangan istilah teknis
///
/// User tidak mau belajar, mereka mau pakai.
class ConsistentGestureHandler extends StatefulWidget {
  final Widget child;
  final GestureConfig? config;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  const ConsistentGestureHandler({
    super.key,
    required this.child,
    this.config,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  @override
  State<ConsistentGestureHandler> createState() =>
      _ConsistentGestureHandlerState();
}

class _ConsistentGestureHandlerState extends State<ConsistentGestureHandler> {
  late GestureConfig _config;
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? GestureConfig.defaultConfig;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      onLongPress: _handleLongPress,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: widget.child,
    );
  }

  void _handleTap() {
    if (!_config.enableTap) return;

    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleDoubleTap() {
    if (!_config.enableDoubleTap) return;

    HapticFeedback.mediumImpact();
    widget.onDoubleTap?.call();
  }

  void _handleLongPress() {
    if (!_config.enableLongPress) return;

    HapticFeedback.heavyImpact();
    widget.onLongPress?.call();
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_config.enableSwipe) return;

    _isDragging = true;
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging || !_config.enableSwipe) return;

    final deltaX = details.globalPosition.dx - _dragStartX;
    final deltaY = details.globalPosition.dy - _dragStartY;

    // Provide visual feedback during swipe
    if (_config.showSwipeFeedback) {
      // TODO: Implement visual feedback
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging || !_config.enableSwipe) return;

    _isDragging = false;

    final deltaX = details.globalPosition.dx - _dragStartX;
    final deltaY = details.globalPosition.dy - _dragStartY;

    final threshold = _config.swipeThreshold;

    // Detect swipe direction
    if (deltaX.abs() > deltaY.abs()) {
      // Horizontal swipe
      if (deltaX > threshold) {
        widget.onSwipeRight?.call();
      } else if (deltaX < -threshold) {
        widget.onSwipeLeft?.call();
      }
    } else {
      // Vertical swipe
      if (deltaY > threshold) {
        widget.onSwipeDown?.call();
      } else if (deltaY < -threshold) {
        widget.onSwipeUp?.call();
      }
    }
  }
}

/// Configuration untuk gesture behavior
class GestureConfig {
  final bool enableTap;
  final bool enableDoubleTap;
  final bool enableLongPress;
  final bool enableSwipe;
  final double swipeThreshold;
  final bool showSwipeFeedback;
  final Duration doubleTapTimeout;

  const GestureConfig({
    this.enableTap = true,
    this.enableDoubleTap = true,
    this.enableLongPress = true,
    this.enableSwipe = true,
    this.swipeThreshold = 50.0,
    this.showSwipeFeedback = true,
    this.doubleTapTimeout = const Duration(milliseconds: 300),
  });

  static const GestureConfig defaultConfig = GestureConfig();

  static const GestureConfig cardConfig = GestureConfig(
    enableTap: true,
    enableDoubleTap: false,
    enableLongPress: true,
    enableSwipe: true,
    swipeThreshold: 80.0,
  );

  static const GestureConfig imageConfig = GestureConfig(
    enableTap: true,
    enableDoubleTap: true,
    enableLongPress: true,
    enableSwipe: false,
  );

  static const GestureConfig listConfig = GestureConfig(
    enableTap: true,
    enableDoubleTap: false,
    enableLongPress: true,
    enableSwipe: true,
    swipeThreshold: 100.0,
  );
}

/// Consistent navigation handler
class ConsistentNavigationHandler extends StatefulWidget {
  final Widget child;
  final bool enableBackGesture;
  final VoidCallback? onBack;

  const ConsistentNavigationHandler({
    super.key,
    required this.child,
    this.enableBackGesture = true,
    this.onBack,
  });

  @override
  State<ConsistentNavigationHandler> createState() =>
      _ConsistentNavigationHandlerState();
}

class _ConsistentNavigationHandlerState
    extends State<ConsistentNavigationHandler> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: widget.enableBackGesture
          ? GestureDetector(onPanEnd: _handleBackGesture, child: widget.child)
          : widget.child,
    );
  }

  Future<bool> _handleWillPop() async {
    HapticFeedback.lightImpact();
    widget.onBack?.call();
    return true;
  }

  void _handleBackGesture(DragEndDetails details) {
    // Detect swipe back gesture (from left edge)
    if (details.primaryVelocity! > 1000) {
      HapticFeedback.lightImpact();
      widget.onBack?.call();
    }
  }
}

/// Swipeable card dengan consistent behavior
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableSwipe;
  final Color? swipeLeftColor;
  final Color? swipeRightColor;
  final Widget? swipeLeftIcon;
  final Widget? swipeRightIcon;

  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onTap,
    this.onLongPress,
    this.enableSwipe = true,
    this.swipeLeftColor,
    this.swipeRightColor,
    this.swipeLeftIcon,
    this.swipeRightIcon,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> {
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        children: [
          // Background for swipe indicators
          if (widget.enableSwipe) _buildSwipeBackground(),

          // Card content
          AnimatedContainer(
            duration: AppTheme.fastDuration,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.mdRadius),
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // Left swipe background
          if (widget.onSwipeRight != null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.swipeRightColor ?? AppTheme.successColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.mdRadius),
                    bottomLeft: Radius.circular(AppTheme.mdRadius),
                  ),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: AppTheme.mdPadding),
                child:
                    widget.swipeRightIcon ??
                    const Icon(Icons.favorite, color: Colors.white, size: 32),
              ),
            ),

          // Right swipe background
          if (widget.onSwipeLeft != null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.swipeLeftColor ?? AppTheme.errorColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppTheme.mdRadius),
                    bottomRight: Radius.circular(AppTheme.mdRadius),
                  ),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppTheme.mdPadding),
                child:
                    widget.swipeLeftIcon ??
                    const Icon(Icons.delete, color: Colors.white, size: 32),
              ),
            ),
        ],
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.enableSwipe) return;

    setState(() {
      _isDragging = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enableSwipe || !_isDragging) return;

    setState(() {
      _dragOffset = details.delta.dx;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enableSwipe || !_isDragging) return;

    final threshold = 100.0;

    setState(() {
      _isDragging = false;

      if (_dragOffset > threshold) {
        // Swipe right
        widget.onSwipeRight?.call();
        HapticFeedback.mediumImpact();
      } else if (_dragOffset < -threshold) {
        // Swipe left
        widget.onSwipeLeft?.call();
        HapticFeedback.mediumImpact();
      }

      // Reset position
      _dragOffset = 0;
    });
  }
}

/// Consistent button dengan proper feedback
class ConsistentButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool fullWidth;
  final bool isLoading;

  const ConsistentButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.fullWidth = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    switch (type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : _handlePress,
          style: _getPrimaryStyle(),
          child: _buildButtonContent(),
        );
      case ButtonType.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : _handlePress,
          style: _getSecondaryStyle(),
          child: _buildButtonContent(),
        );
      case ButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : _handlePress,
          style: _getTextStyle(),
          child: _buildButtonContent(),
        );
    }
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        height: _getButtonHeight(),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (icon != null) {
      children.add(Icon(icon, size: _getIconSize()));
      children.add(const SizedBox(width: AppTheme.smSpacing));
    }

    children.add(Text(text));

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  ButtonStyle _getPrimaryStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _getButtonColor(),
      foregroundColor: Colors.white,
      padding: _getButtonPadding(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
      elevation: AppTheme.smElevation,
    );
  }

  ButtonStyle _getSecondaryStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _getButtonColor(),
      side: BorderSide(color: _getButtonColor()),
      padding: _getButtonPadding(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
    );
  }

  ButtonStyle _getTextStyle() {
    return TextButton.styleFrom(
      foregroundColor: _getButtonColor(),
      padding: _getButtonPadding(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
    );
  }

  Color _getButtonColor() {
    switch (type) {
      case ButtonType.primary:
        return AppTheme.primaryColor;
      case ButtonType.secondary:
        return AppTheme.secondaryTextColor;
      case ButtonType.text:
        return AppTheme.primaryColor;
    }
  }

  EdgeInsets _getButtonPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.smPadding,
          vertical: AppTheme.xsPadding,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.mdPadding,
          vertical: AppTheme.smPadding,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.lgPadding,
          vertical: AppTheme.mdPadding,
        );
    }
  }

  double _getButtonHeight() {
    switch (size) {
      case ButtonSize.small:
        return 32;
      case ButtonSize.medium:
        return 40;
      case ButtonSize.large:
        return 48;
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
    }
  }

  void _handlePress() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }
}

enum ButtonType { primary, secondary, text }

enum ButtonSize { small, medium, large }

/// Utility untuk consistent navigation
class NavigationHelper {
  static void navigateWithSlide(
    BuildContext context,
    Widget destination, {
    bool slideRight = false,
  }) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = slideRight ? Offset(-1.0, 0.0) : Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppTheme.normalDuration,
      ),
    );
  }

  static void navigateBackWithSlide(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  static void showModalWithFade(
    BuildContext context,
    Widget modal, {
    bool barrierDismissible = true,
  }) {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) =>
          AnimatedContainer(duration: AppTheme.normalDuration, child: modal),
    );
  }
}

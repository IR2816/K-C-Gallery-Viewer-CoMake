import 'dart:async';
import 'package:flutter/material.dart';

/// Shows an animated slide-in/slide-out toast notification when the domain
/// changes.
///
/// Call [DomainChangeNotifier.show] as a static helper to overlay the
/// notification over the current route.
class DomainChangeNotifier extends StatefulWidget {
  final String oldDomain;
  final String newDomain;
  final String apiSource;
  final VoidCallback? onDismiss;

  const DomainChangeNotifier({
    super.key,
    required this.oldDomain,
    required this.newDomain,
    required this.apiSource,
    this.onDismiss,
  });

  /// Convenience method: insert the notification as an overlay entry.
  static void show(
    BuildContext context, {
    required String oldDomain,
    required String newDomain,
    required String apiSource,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => DomainChangeNotifier(
        oldDomain: oldDomain,
        newDomain: newDomain,
        apiSource: apiSource,
        onDismiss: () => entry?.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<DomainChangeNotifier> createState() => _DomainChangeNotifierState();
}

class _DomainChangeNotifierState extends State<DomainChangeNotifier>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoHideTimer;

  static const Color _kemonoColor = Color(0xFF2196F3);
  static const Color _coomerColor = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto-dismiss after 2.5 s
    _autoHideTimer = Timer(const Duration(milliseconds: 2500), _dismiss);
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss?.call();
  }

  Color get _accentColor =>
      widget.apiSource.toLowerCase() == 'coomer' ? _coomerColor : _kemonoColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom:
          MediaQuery.of(context).viewInsets.bottom +
          MediaQuery.of(context).padding.bottom +
          16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C2E)
                    : Colors.white,
                border: Border.all(color: _accentColor.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Animated success icon
                  _buildCheckIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.apiSource.toUpperCase()} domain updated',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _domainChip(
                              widget.oldDomain,
                              Colors.grey,
                              strikethrough: true,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: _accentColor,
                              ),
                            ),
                            _domainChip(widget.newDomain, _accentColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.grey.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentColor.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: _accentColor,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _domainChip(String domain, Color color, {bool strikethrough = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        domain,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

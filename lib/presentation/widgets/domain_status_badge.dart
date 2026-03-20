import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// Color-coded domain status badge widget.
///
/// - Kemono = Blue (#2196F3)
/// - Coomer = Orange/Red (#FF6B6B)
///
/// Animates its color transition (400 ms) when the domain changes.
class DomainStatusBadge extends StatefulWidget {
  final String apiSource; // 'kemono' or 'coomer'
  final bool compact;

  const DomainStatusBadge({
    super.key,
    required this.apiSource,
    this.compact = false,
  });

  @override
  State<DomainStatusBadge> createState() => _DomainStatusBadgeState();
}

class _DomainStatusBadgeState extends State<DomainStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _pulseAnimation;

  Color _previousColor = Colors.transparent;
  String _previousDomain = '';

  static const Color _kemonoColor = Color(0xFF2196F3);
  static const Color _coomerColor = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final baseColor = _colorForSource(widget.apiSource);
    _previousColor = baseColor;
    _colorAnimation = ColorTween(begin: baseColor, end: baseColor)
        .animate(_controller);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorForSource(String source) =>
      source.toLowerCase() == 'coomer' ? _coomerColor : _kemonoColor;

  void _triggerAnimation(Color from, Color to) {
    _previousColor = from;
    _colorAnimation = ColorTween(begin: from, end: to).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final domain = widget.apiSource.toLowerCase() == 'coomer'
            ? settings.cleanCoomerDomain
            : settings.cleanKemonoDomain;
        final targetColor = _colorForSource(widget.apiSource);

        // Detect domain change → trigger animation
        if (domain != _previousDomain && _previousDomain.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _triggerAnimation(_previousColor, targetColor);
          });
        }
        _previousDomain = domain;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final color = _colorAnimation.value ?? targetColor;
            return Transform.scale(
              scale: _controller.isAnimating ? _pulseAnimation.value : 1.0,
              child: Tooltip(
                message: domain,
                child: Container(
                  padding: widget.compact
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                      : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(widget.compact ? 6 : 8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated active indicator dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.compact
                            ? domain
                            : '${widget.apiSource.toUpperCase()} · $domain',
                        style: TextStyle(
                          fontSize: widget.compact ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A thin wrapper around [RefreshIndicator] that enforces consistent
/// styling (colour, background) across every pull-to-refresh surface
/// in the app.
///
/// Replace every bare [RefreshIndicator] call with [RefreshWrapper] so
/// the indicator colour is never specified ad-hoc.
///
/// The optional [color] parameter is intentionally omitted from most
/// call sites; override it only when a specific screen genuinely needs
/// a different accent (e.g. a per-service-branded indicator).
class RefreshWrapper extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Override the indicator colour only when the default [AppTheme.primaryColor]
  /// is inappropriate for the context. Leave `null` to use the app-wide default.
  final Color? color;

  const RefreshWrapper({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? AppTheme.primaryColor,
      backgroundColor: AppTheme.getSurfaceColor(context),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A thin wrapper around [RefreshIndicator] that enforces consistent
/// styling (colour, background) across every pull-to-refresh surface
/// in the app.
///
/// Replace every bare [RefreshIndicator] call with [RefreshWrapper] so
/// the indicator colour is never specified ad-hoc.
class RefreshWrapper extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
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

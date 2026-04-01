import 'package:flutter/material.dart';

/// Consolidates the common loading/error/empty/content branches.
class StateAwareBuilder<T> extends StatelessWidget {
  const StateAwareBuilder({
    super.key,
    required this.isLoading,
    required this.items,
    required this.builder,
    this.error,
    this.onRetry,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
  });

  final bool isLoading;
  final List<T> items;
  final String? error;
  final VoidCallback? onRetry;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(String message, VoidCallback? onRetry)? errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final Widget Function(List<T> items) builder;

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }

    if (error != null && items.isEmpty) {
      return errorBuilder?.call(error!, onRetry) ??
          _DefaultErrorState(message: error!, onRetry: onRetry);
    }

    if (items.isEmpty) {
      return emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }

    return builder(items);
  }
}

class _DefaultErrorState extends StatelessWidget {
  const _DefaultErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

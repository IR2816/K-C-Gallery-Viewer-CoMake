import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Prinsip 5: Error handling yang manusiawi
///
/// 5.1 Error ≠ pesan teknis
/// ❌ Jangan: "Network error 502"
/// ✅ Ganti: "Gagal memuat konten. Coba lagi."
/// Tambahkan: Tombol retry, tanpa menyalahkan user
///
/// 5.2 Media gagal load ≠ crash
/// Kalau image/video gagal:
/// - Tampilkan placeholder
/// - Beri opsi reload
///
/// App yang "kuat" = tidak panik saat gagal.
class HumanErrorHandler extends StatelessWidget {
  final ErrorType errorType;
  final String? customMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Widget? customIcon;
  final bool showRetryButton;
  final bool showDismissButton;

  const HumanErrorHandler({
    super.key,
    required this.errorType,
    this.customMessage,
    this.onRetry,
    this.onDismiss,
    this.customIcon,
    this.showRetryButton = true,
    this.showDismissButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Error icon
          _buildErrorIcon(),

          const SizedBox(height: AppTheme.mdSpacing),

          // Error title
          Text(
            _getErrorTitle(),
            style: AppTheme.titleStyle,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppTheme.smSpacing),

          // Error message
          Text(
            customMessage ?? _getErrorMessage(),
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppTheme.lgSpacing),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildErrorIcon() {
    if (customIcon != null) {
      return customIcon!;
    }

    switch (errorType) {
      case ErrorType.network:
        return Icon(Icons.wifi_off, size: 64, color: AppTheme.errorColor);
      case ErrorType.server:
        return Icon(Icons.cloud_off, size: 64, color: AppTheme.errorColor);
      case ErrorType.notFound:
        return Icon(Icons.search_off, size: 64, color: AppTheme.warningColor);
      case ErrorType.timeout:
        return Icon(Icons.access_time, size: 64, color: AppTheme.warningColor);
      case ErrorType.media:
        return Icon(Icons.broken_image, size: 64, color: AppTheme.errorColor);
      case ErrorType.permission:
        return Icon(Icons.lock, size: 64, color: AppTheme.warningColor);
      case ErrorType.unknown:
        return Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor);
    }
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    if (showRetryButton && onRetry != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onRetry?.call();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Coba Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.primaryTextColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lgPadding,
              vertical: AppTheme.smPadding,
            ),
          ),
        ),
      );
    }

    if (showDismissButton && onDismiss != null) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: AppTheme.smSpacing));
      }

      buttons.add(
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            onDismiss?.call();
          },
          icon: const Icon(Icons.close),
          label: const Text('Tutup'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.secondaryTextColor,
            side: BorderSide(color: AppTheme.secondaryTextColor),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lgPadding,
              vertical: AppTheme.smPadding,
            ),
          ),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: buttons);
  }

  String _getErrorTitle() {
    switch (errorType) {
      case ErrorType.network:
        return 'Koneksi Bermasalah';
      case ErrorType.server:
        return 'Server Sedang Sibuk';
      case ErrorType.notFound:
        return 'Konten Tidak Ditemukan';
      case ErrorType.timeout:
        return 'Waktu Habis';
      case ErrorType.media:
        return 'Media Gagal Dimuat';
      case ErrorType.permission:
        return 'Izin Diperlukan';
      case ErrorType.unknown:
        return 'Terjadi Kesalahan';
    }
  }

  String _getErrorMessage() {
    switch (errorType) {
      case ErrorType.network:
        return 'Periksa koneksi internet Anda dan coba lagi.';
      case ErrorType.server:
        return 'Server sedang dalam perbaikan. Silakan coba beberapa saat lagi.';
      case ErrorType.notFound:
        return 'Konten yang Anda cari tidak tersedia atau telah dihapus.';
      case ErrorType.timeout:
        return 'Permintaan terlalu lama. Periksa koneksi dan coba lagi.';
      case ErrorType.media:
        return 'Gagal memuat gambar atau video. Coba refresh halaman ini.';
      case ErrorType.permission:
        return 'Aplikasi memerlukan izin untuk melanjutkan.';
      case ErrorType.unknown:
        return 'Terjadi kesalahan yang tidak terduga. Silakan coba lagi.';
    }
  }
}

/// Error types untuk human-friendly handling
enum ErrorType {
  network,
  server,
  notFound,
  timeout,
  media,
  permission,
  unknown,
}

/// Media error handler khusus untuk gambar/video
class MediaErrorHandler extends StatelessWidget {
  final String mediaUrl;
  final MediaType mediaType;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Widget? placeholder;

  const MediaErrorHandler({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.onRetry,
    this.onDismiss,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Media-specific icon
          Icon(
            mediaType == MediaType.image
                ? Icons.broken_image
                : Icons.videocam_off,
            size: 48,
            color: AppTheme.secondaryTextColor,
          ),

          const SizedBox(height: AppTheme.smSpacing),

          // Error message
          Text(
            mediaType == MediaType.image
                ? 'Gambar gagal dimuat'
                : 'Video gagal dimuat',
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),

          const SizedBox(height: AppTheme.smSpacing),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onRetry != null)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onRetry?.call();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Coba Lagi'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),

              if (onDismiss != null) ...[
                const SizedBox(width: AppTheme.smSpacing),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDismiss?.call();
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Tutup'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

enum MediaType { image, video }

/// Network error handler dengan auto-retry
class NetworkErrorHandler extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRetry;
  final int maxRetries;
  final Duration retryDelay;

  const NetworkErrorHandler({
    super.key,
    required this.child,
    this.onRetry,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  });

  @override
  State<NetworkErrorHandler> createState() => _NetworkErrorHandlerState();
}

class _NetworkErrorHandlerState extends State<NetworkErrorHandler> {
  bool _hasError = false;
  int _retryCount = 0;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return HumanErrorHandler(
        errorType: ErrorType.network,
        onRetry: _handleRetry,
        showRetryButton: _retryCount < widget.maxRetries,
        customMessage: _retryCount >= widget.maxRetries
            ? 'Gagal memuat setelah beberapa kali percobaan. Periksa koneksi Anda.'
            : null,
      );
    }

    return widget.child;
  }

  Future<void> _handleRetry() async {
    if (_retryCount >= widget.maxRetries) return;

    setState(() {
      _hasError = false;
      _retryCount++;
    });

    HapticFeedback.mediumImpact();

    try {
      await widget.onRetry?.call();
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  void showError() {
    setState(() {
      _hasError = true;
    });
  }

  void clearError() {
    setState(() {
      _hasError = false;
      _retryCount = 0;
    });
  }
}

/// Utility untuk menampilkan error dialogs
class ErrorDialogHelper {
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    bool barrierDismissible = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(title, style: AppTheme.titleStyle),
        content: Text(message, style: AppTheme.bodyStyle),
        actions: [
          if (onAction != null && actionText != null)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(
                actionText,
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  static void showNetworkErrorDialog(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showErrorDialog(
      context,
      title: 'Koneksi Bermasalah',
      message:
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      actionText: 'Coba Lagi',
      onAction: onRetry,
    );
  }

  static void showServerErrorDialog(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showErrorDialog(
      context,
      title: 'Server Sedang Sibuk',
      message:
          'Server sedang dalam perbaikan. Silakan coba beberapa saat lagi.',
      actionText: 'Coba Lagi',
      onAction: onRetry,
    );
  }

  static void showPermissionErrorDialog(
    BuildContext context, {
    required String permission,
    VoidCallback? onRequestPermission,
  }) {
    showErrorDialog(
      context,
      title: 'Izin Diperlukan',
      message:
          'Aplikasi memerlukan izin $permission untuk berfungsi dengan baik.',
      actionText: 'Berikan Izin',
      onAction: onRequestPermission,
    );
  }
}

/// SnackBar helper untuk error messages
class ErrorSnackBarHelper {
  static void showErrorSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? action,
    String? actionLabel,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: AppTheme.errorColor,
        action: action != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: action,
              )
            : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
        ),
      ),
    );
  }

  static void showNetworkErrorSnackBar(BuildContext context) {
    showErrorSnackBar(
      context,
      message: 'Koneksi internet bermasalah',
      actionLabel: 'Coba Lagi',
      action: () {
        // TODO: Implement retry logic
      },
    );
  }

  static void showSuccessSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
        ),
      ),
    );
  }
}

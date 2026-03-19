import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'logger.dart';

/// Global error handler for uncaught Flutter and platform errors.
///
/// Call [AppErrorHandler.initialize] once at app startup (before [runApp])
/// to catch all unhandled exceptions and log them via [AppLogger].
///
/// ### Firebase Crashlytics
/// Errors are automatically forwarded to Firebase Crashlytics when the app
/// is running in release/profile mode and Firebase has been initialized.
class AppErrorHandler {
  AppErrorHandler._();

  /// Set up global Flutter and platform error handlers.
  static void initialize() {
    // Catch widget-layer errors (layout overflows, assertion failures, etc.)
    FlutterError.onError = _onFlutterError;

    // Catch errors originating outside the Flutter widget tree (e.g. async
    // errors, Dart isolate errors).
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error(
        'Uncaught platform error',
        tag: 'ErrorHandler',
        error: error,
        stackTrace: stack,
      );

      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {
        // Firebase may not be initialized (e.g. missing google-services.json).
      }

      return true;
    };

    AppLogger.info('Global error handler initialized', tag: 'ErrorHandler');
  }

  static void _onFlutterError(FlutterErrorDetails details) {
    AppLogger.error(
      'Uncaught Flutter error: ${details.exceptionAsString()}',
      tag: 'ErrorHandler',
      error: details.exception,
      stackTrace: details.stack,
    );

    // Forward to the default Flutter handler so the red-screen is shown
    // in debug mode and the error is printed to the console.
    FlutterError.presentError(details);

    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {
      // Firebase may not be initialized (e.g. missing google-services.json).
    }
  }
}

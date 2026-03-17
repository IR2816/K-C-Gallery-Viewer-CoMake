import 'package:flutter/foundation.dart';
import 'logger.dart';

/// Global error handler for uncaught Flutter and platform errors.
///
/// Call [AppErrorHandler.initialize] once at app startup (before [runApp])
/// to catch all unhandled exceptions and log them via [AppLogger].
///
/// ### Firebase Crashlytics
/// Once the project is configured with `google-services.json` /
/// `GoogleService-Info.plist`, add the `firebase_crashlytics` import and
/// replace the two TODO stubs below to forward errors to Crashlytics:
///
/// ```dart
/// // In _onFlutterError:
/// FirebaseCrashlytics.instance.recordFlutterFatalError(details);
///
/// // In PlatformDispatcher.instance.onError:
/// FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
/// ```
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

      // TODO: when Firebase is configured, add:
      // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);

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

    // TODO: when Firebase is configured, add:
    // FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }
}

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

enum SnackbarType { success, error, warning, info }

class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String message,
    String? title,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastificationType toastType;
    switch (type) {
      case SnackbarType.success:
        toastType = ToastificationType.success;
        break;
      case SnackbarType.error:
        toastType = ToastificationType.error;
        break;
      case SnackbarType.warning:
        toastType = ToastificationType.warning;
        break;
      case SnackbarType.info:
        toastType = ToastificationType.info;
        break;
    }

    toastification.show(
      context: context,
      type: toastType,
      style: ToastificationStyle.flatColored,
      title: title != null ? Text(title) : Text(message),
      description: title != null ? Text(message) : null,
      alignment: Alignment.topCenter,
      autoCloseDuration: duration,
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: lowModeShadow,
      showProgressBar: false,
      applyBlurEffect: true,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) => show(
    context: context,
    message: message,
    title: title,
    type: SnackbarType.success,
  );

  static void showError(
    BuildContext context,
    String message, {
    String? title,
  }) => show(
    context: context,
    message: message,
    title: title,
    type: SnackbarType.error,
    duration: const Duration(seconds: 5),
  );

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) => show(
    context: context,
    message: message,
    title: title,
    type: SnackbarType.warning,
  );

  static void showInfo(BuildContext context, String message, {String? title}) =>
      show(
        context: context,
        message: message,
        title: title,
        type: SnackbarType.info,
      );
}

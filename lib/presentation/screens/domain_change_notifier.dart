import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DomainChangeNotifier extends ChangeNotifier {
  void notifyDomainChange(String domain) {
    // Notify listeners
    notifyListeners();

    // Show toast notification
    Fluttertoast.showToast(
      msg: "Domain changed to: $domain",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  static void show(
    BuildContext context, {
    required String oldDomain,
    required String newDomain,
    required String apiSource,
  }) {
    Fluttertoast.showToast(
      msg: "$apiSource domain changed from $oldDomain to $newDomain",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
}

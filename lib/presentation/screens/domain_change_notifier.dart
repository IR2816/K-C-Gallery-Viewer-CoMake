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
}

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class NotificationToast {
  static void show(
    String message, {
    ToastGravity gravity = ToastGravity.BOTTOM,
    Duration duration = const Duration(seconds: 2),
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey.shade800,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  static void showSuccess(String message) {
    show('✅ $message');
  }

  static void showError(String message) {
    show('❌ $message');
  }

  static void showInfo(String message) {
    show('ℹ️ $message');
  }

  static void showWarning(String message) {
    show('⚠️ $message');
  }
}

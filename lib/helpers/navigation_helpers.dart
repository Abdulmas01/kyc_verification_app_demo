import 'package:flutter/material.dart';

class NavigationHelpers {
  static final navigationKey = GlobalKey<NavigatorState>();

  static void pushAndClearStackFromNavigator({
    required Widget route,
    NavigatorState? navigator,
  }) {
    navigationKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => route),
      (route) => false,
    );
  }
}

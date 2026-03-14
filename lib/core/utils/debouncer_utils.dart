import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/utils/logger.dart';

/// A utility class to debounce actions.
///
/// Use this debouncer to delay the execution of a function until a specified
/// duration has passed since the last call.
class DebouncerUtils {
  final Duration delay;
  Timer? _timer;

  DebouncerUtils({required this.delay});

  /// Runs the provided [action] after the debounce [delay].
  /// If called again before the timer completes, the previous timer is cancelled.
  void run(VoidCallback action) {
    _timer?.cancel();
    logger.i("DebouncerUtils: Scheduling action in ${delay.inMilliseconds} ms");
    _timer = Timer(delay, () {
      logger.i("DebouncerUtils: Executing debounced action");
      action();
      _timer = null;
    });
  }

  /// Cancels any pending debounced action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}

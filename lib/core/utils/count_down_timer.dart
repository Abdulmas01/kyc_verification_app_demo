import 'dart:async';
import 'dart:ui';

class CountdownTimer {
  final int initialSeconds;
  final void Function(int remaining) onTick;
  final VoidCallback onFinished;

  Timer? _timer;
  int _remaining;

  CountdownTimer({
    required this.initialSeconds,
    required this.onTick,
    required this.onFinished,
  }) : _remaining = 0;

  void start() {
    _remaining = initialSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 0) {
        timer.cancel();
        onFinished();
      } else {
        _remaining--;
        onTick(_remaining);
      }
    });
  }

  void reset() => start();

  void cancel() => _timer?.cancel();
}

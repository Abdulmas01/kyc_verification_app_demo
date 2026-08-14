import 'dart:async';

import 'package:camera/camera.dart';

class CameraLifecycleCoordinator {
  CameraLifecycleCoordinator({
    required this.logPrefix,
    required this.logger,
  });

  final String logPrefix;
  final void Function(String message) logger;

  Future<void> _transitionFuture = Future.value();
  Future<void>? _disposeFuture;
  bool _isStreaming = false;
  bool _isRouteActive = true;
  bool _isDisposed = false;

  bool get isStreaming => _isStreaming;
  bool get isRouteActive => _isRouteActive;
  bool get isDisposed => _isDisposed;

  void markRouteActive([bool value = true]) {
    _isRouteActive = value;
  }

  void markDisposed() {
    _isDisposed = true;
    _isRouteActive = false;
  }

  void syncStreamingFromController(CameraController? controller) {
    _isStreaming = controller?.value.isStreamingImages ?? false;
  }

  Future<void> queueTransition(Future<void> Function() operation) {
    final next = _transitionFuture.catchError((_) {}).then((_) async {
      if (_isDisposed) return;
      await operation();
    });
    _transitionFuture = next;
    return next;
  }

  Future<void> startImageStream({
    required CameraController? controller,
    required void Function(CameraImage image) onImage,
  }) {
    return queueTransition(() async {
      if (!_isRouteActive || _isDisposed) return;
      await startImageStreamImmediate(
        controller: controller,
        onImage: onImage,
      );
    });
  }

  Future<void> startImageStreamImmediate({
    required CameraController? controller,
    required void Function(CameraImage image) onImage,
  }) async {
    if (!_isRouteActive || _isDisposed) return;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      _isStreaming = true;
      return;
    }
    if (_isStreaming) return;
    await controller.startImageStream(onImage);
    _isStreaming = true;
  }

  Future<void> stopImageStream(CameraController? controller) {
    return queueTransition(() => stopImageStreamImmediate(controller));
  }

  Future<void> stopImageStreamImmediate(CameraController? controller) async {
    if (controller == null) {
      _isStreaming = false;
      return;
    }
    if (!(controller.value.isStreamingImages || _isStreaming)) {
      _isStreaming = false;
      return;
    }
    try {
      await controller.stopImageStream();
    } on CameraException catch (error) {
      logger('$logPrefix stop stream ignored: ${error.code}');
    } catch (_) {
      logger('$logPrefix stop stream ignored.');
    }
    _isStreaming = false;
  }

  Future<void> disposeController(CameraController? controller) async {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    late final Future<void> future;
    future = _disposeControllerInternal(controller).whenComplete(() {
      if (identical(_disposeFuture, future)) {
        _disposeFuture = null;
      }
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _disposeControllerInternal(CameraController? controller) async {
    _isStreaming = false;
    if (controller == null) return;
    await stopImageStreamImmediate(controller);
    try {
      await controller.dispose();
    } on CameraException catch (error) {
      logger('$logPrefix dispose ignored: ${error.code}');
    } catch (_) {
      logger('$logPrefix dispose ignored.');
    }
  }
}

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/logger.dart';
class QualityIsolate {
  QualityIsolate({required this.assetPath});

  final String assetPath;
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _sendPort;
  Isolate? _isolate;
  int _nextId = 0;
  final Map<int, Completer<List<double>>> _pending = {};
  Future<void>? _startFuture;

  Future<void> start() async {
    if (_startFuture != null) return _startFuture;
    final completer = Completer<void>();
    _startFuture = completer.future;
    final ready = Completer<SendPort>();
    var metaLogged = false;
    _receivePort.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      if (message is Map) {
        final meta = message['meta'];
        if (!metaLogged && meta is Map) {
          metaLogged = true;
          logPrint(
            'QualityIsolate meta: '
            'format=${meta['format']}, '
            'size=${meta['width']}x${meta['height']}, '
            'planes=${meta['planes']}, '
            'p0r=${meta['p0r']}, p0p=${meta['p0p']}, '
            'p1r=${meta['p1r']}, p1p=${meta['p1p']}, '
            'p2r=${meta['p2r']}, p2p=${meta['p2p']}, '
            'inputShape=${meta['inputShape']}, '
            'outputShape=${meta['outputShape']}',
          );
          return;
        }
        final id = message['id'] as int?;
        final probs = message['probs'] as List<double>?;
        final error = message['error'] as String?;
        if (id != null && probs != null) {
          _pending.remove(id)?.complete(probs);
          return;
        }
        if (id != null && error != null) {
          _pending.remove(id)?.completeError(StateError(error));
        }
      }
    });

    final rootToken = RootIsolateToken.instance;
    if (rootToken == null) {
      throw StateError(
        'RootIsolateToken is null. Ensure WidgetsFlutterBinding is initialized.',
      );
    }
    final assetData = await rootBundle.load(assetPath);
    final modelData = TransferableTypedData.fromList([
      assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      ),
    ]);

    _isolate = await Isolate.spawn<_IsolateConfig>(
      _entry,
      _IsolateConfig(
        _receivePort.sendPort,
        rootToken,
        modelData,
      ),
    );
    _sendPort = await ready.future;
    completer.complete();
  }

  Future<List<double>?> predict(CameraImage image) async {
    final payload = _FramePayload.fromCameraImage(image);
    return predictPayload(payload.toMap());
  }

  Map<String, Object?> buildPayload(CameraImage image) {
    return _FramePayload.fromCameraImage(image).toMap();
  }

  Future<List<double>?> predictPayload(Map<String, Object?> payload) async {
    if (_sendPort == null) {
      throw StateError('QualityIsolate not started');
    }
    final id = _nextId++;
    final completer = Completer<List<double>>();
    _pending[id] = completer;

    _sendPort!.send({
      'id': id,
      'payload': payload,
    });
    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Quality inference timed out');
      },
    );
  }

  Future<void> dispose() async {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Isolate disposed'));
      }
    }
    _pending.clear();
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _startFuture = null;
  }
}

class _IsolateConfig {
  _IsolateConfig(
    this.sendPort,
    this.rootToken,
    this.modelData,
  );

  final SendPort sendPort;
  final RootIsolateToken rootToken;
  final TransferableTypedData modelData;
}

class _FramePayload {
  _FramePayload({
    required this.width,
    required this.height,
    required this.format,
    required this.plane0,
    required this.plane0RowStride,
    required this.plane0PixelStride,
    this.plane1,
    this.plane1RowStride,
    this.plane1PixelStride,
    this.plane2,
    this.plane2RowStride,
    this.plane2PixelStride,
  });

  final int width;
  final int height;
  final int format;
  final TransferableTypedData plane0;
  final int plane0RowStride;
  final int plane0PixelStride;
  final TransferableTypedData? plane1;
  final int? plane1RowStride;
  final int? plane1PixelStride;
  final TransferableTypedData? plane2;
  final int? plane2RowStride;
  final int? plane2PixelStride;

  static _FramePayload fromCameraImage(CameraImage image) {
    final p0 = image.planes[0];
    final p1 = image.planes.length > 1 ? image.planes[1] : null;
    final p2 = image.planes.length > 2 ? image.planes[2] : null;

    return _FramePayload(
      width: image.width,
      height: image.height,
      format: image.format.group.index,
      plane0: TransferableTypedData.fromList([p0.bytes]),
      plane0RowStride: p0.bytesPerRow,
      plane0PixelStride: p0.bytesPerPixel ?? 1,
      plane1: p1 == null ? null : TransferableTypedData.fromList([p1.bytes]),
      plane1RowStride: p1?.bytesPerRow,
      plane1PixelStride: p1?.bytesPerPixel,
      plane2: p2 == null ? null : TransferableTypedData.fromList([p2.bytes]),
      plane2RowStride: p2?.bytesPerRow,
      plane2PixelStride: p2?.bytesPerPixel,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'w': width,
      'h': height,
      'f': format,
      'p0': plane0,
      'p1': plane1,
      'p2': plane2,
      'p0r': plane0RowStride,
      'p0p': plane0PixelStride,
      'p1r': plane1RowStride,
      'p1p': plane1PixelStride,
      'p2r': plane2RowStride,
      'p2p': plane2PixelStride,
    };
  }

  static _FramePayload fromMap(Map<dynamic, dynamic> map) {
    return _FramePayload(
      width: map['w'] as int,
      height: map['h'] as int,
      format: map['f'] as int,
      plane0: map['p0'] as TransferableTypedData,
      plane0RowStride: map['p0r'] as int,
      plane0PixelStride: map['p0p'] as int,
      plane1: map['p1'] as TransferableTypedData?,
      plane1RowStride: map['p1r'] as int?,
      plane1PixelStride: map['p1p'] as int?,
      plane2: map['p2'] as TransferableTypedData?,
      plane2RowStride: map['p2r'] as int?,
      plane2PixelStride: map['p2p'] as int?,
    );
  }
}

Future<void> _entry(_IsolateConfig config) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(config.rootToken);
  final receivePort = ReceivePort();
  config.sendPort.send(receivePort.sendPort);

  final modelBytes = config.modelData.materialize().asUint8List();
  final interpreter = await Interpreter.fromBuffer(
    modelBytes,
    options: InterpreterOptions()..threads = 2,
  );

  final inputShape = interpreter.getInputTensor(0).shape;
  final outputShape = interpreter.getOutputTensor(0).shape;
  final inputHeight = inputShape.length > 1 ? inputShape[1] : 224;
  final inputWidth = inputShape.length > 2 ? inputShape[2] : 224;
  final inputChannels = inputShape.length > 3 ? inputShape[3] : 3;

  if (inputChannels != 3) {
    throw StateError('Unsupported input channels: $inputChannels');
  }

  var metaSent = false;
  receivePort.listen((message) {
    if (message is! Map) return;
    final id = message['id'] as int?;
    final payloadMap = message['payload'];
    if (id == null || payloadMap is! Map) return;

    try {
      final payload = _FramePayload.fromMap(payloadMap);
      if (!metaSent) {
        metaSent = true;
        config.sendPort.send({
          'meta': {
            'format': payload.format,
            'width': payload.width,
            'height': payload.height,
            'planes': [
              true,
              payload.plane1 != null,
              payload.plane2 != null,
            ],
            'p0r': payload.plane0RowStride,
            'p0p': payload.plane0PixelStride,
            'p1r': payload.plane1RowStride,
            'p1p': payload.plane1PixelStride,
            'p2r': payload.plane2RowStride,
            'p2p': payload.plane2PixelStride,
            'inputShape': inputShape,
            'outputShape': outputShape,
          },
        });
      }
      final image = _imageFromPayload(payload);
      final resized = img.copyResize(
        image,
        width: inputWidth,
        height: inputHeight,
      );
      final input = _imageToTensor(resized, inputWidth, inputHeight);
      final output = _createOutputBuffer(outputShape);
      interpreter.run(input, output);
      final probs = _flattenOutput(output);

      config.sendPort.send({'id': id, 'probs': probs});
    } catch (e) {
      config.sendPort.send({'id': id, 'error': e.toString()});
    }
  });
}

img.Image _imageFromPayload(_FramePayload payload) {
  if (payload.format == ImageFormatGroup.yuv420.index) {
    return _yuvToImage(payload);
  }
  if (payload.format == ImageFormatGroup.bgra8888.index) {
    return _bgraToImage(payload);
  }
  throw StateError('Unsupported image format: ${payload.format}');
}

img.Image _yuvToImage(_FramePayload payload) {
  final uPlane = payload.plane1;
  final vPlane = payload.plane2;
  if (uPlane == null || vPlane == null) {
    throw StateError('Missing UV planes for YUV420 frame');
  }
  final uvRowStride = payload.plane1RowStride;
  final uvPixelStride = payload.plane1PixelStride;
  if (uvRowStride == null || uvPixelStride == null) {
    throw StateError('Missing UV plane stride for YUV420 frame');
  }

  final yBytes = payload.plane0.materialize().asUint8List();
  final uBytes = uPlane.materialize().asUint8List();
  final vBytes = vPlane.materialize().asUint8List();

  final rgbBytes = Uint8List(payload.width * payload.height * 3);
  var idx = 0;

  for (int y = 0; y < payload.height; y++) {
    final int yRow = y * payload.plane0RowStride;
    final int uvRow = (y >> 1) * uvRowStride;
    for (int x = 0; x < payload.width; x++) {
      final int yp = yBytes[yRow + x];
      final int uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final int up = uBytes[uvIndex];
      final int vp = vBytes[uvIndex];

      final r = (yp + 1.402 * (vp - 128)).clamp(0, 255).toInt();
      final g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128))
          .clamp(0, 255)
          .toInt();
      final b = (yp + 1.772 * (up - 128)).clamp(0, 255).toInt();

      rgbBytes[idx++] = r;
      rgbBytes[idx++] = g;
      rgbBytes[idx++] = b;
    }
  }

  return img.Image.fromBytes(
    width: payload.width,
    height: payload.height,
    bytes: rgbBytes.buffer,
    numChannels: 3,
  );
}

img.Image _bgraToImage(_FramePayload payload) {
  final bgraBytes = payload.plane0.materialize().asUint8List();
  final rowStride = payload.plane0RowStride;
  final pixelStride = payload.plane0PixelStride;
  if (pixelStride < 3) {
    throw StateError('Invalid BGRA pixel stride: $pixelStride');
  }

  final rgbBytes = Uint8List(payload.width * payload.height * 3);
  var idx = 0;

  for (int y = 0; y < payload.height; y++) {
    final int row = y * rowStride;
    for (int x = 0; x < payload.width; x++) {
      final int offset = row + x * pixelStride;
      final int b = bgraBytes[offset];
      final int g = bgraBytes[offset + 1];
      final int r = bgraBytes[offset + 2];
      rgbBytes[idx++] = r;
      rgbBytes[idx++] = g;
      rgbBytes[idx++] = b;
    }
  }

  return img.Image.fromBytes(
    width: payload.width,
    height: payload.height,
    bytes: rgbBytes.buffer,
    numChannels: 3,
  );
}

List<List<List<List<double>>>> _imageToTensor(
  img.Image image,
  int width,
  int height,
) {
  const mean = [0.485, 0.456, 0.406];
  const std = [0.229, 0.224, 0.225];
  return [
    List.generate(
      height,
      (y) => List.generate(width, (x) {
        final pixel = image.getPixel(x, y);
        return [
          (pixel.r / 255.0 - mean[0]) / std[0],
          (pixel.g / 255.0 - mean[1]) / std[1],
          (pixel.b / 255.0 - mean[2]) / std[2],
        ];
      }),
    ),
  ];
}

dynamic _createOutputBuffer(List<int> shape) {
  if (shape.isEmpty) return 0.0;
  if (shape.length == 1) {
    return List<double>.filled(shape[0], 0.0);
  }
  return List.generate(
    shape[0],
    (_) => _createOutputBuffer(shape.sublist(1)),
  );
}

List<double> _flattenOutput(dynamic output) {
  final result = <double>[];
  void walk(dynamic node) {
    if (node is double) {
      result.add(node);
    } else if (node is num) {
      result.add(node.toDouble());
    } else if (node is List) {
      for (final item in node) {
        walk(item);
      }
    }
  }

  walk(output);
  return result;
}

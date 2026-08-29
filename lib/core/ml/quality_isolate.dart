import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/logger.dart';
import '../utils/app_assets.dart';
import '../utils/image_utils.dart';
import 'document_quality_contract.dart';
import 'model_contract_types.dart';

class QualityDebugArtifacts {
  const QualityDebugArtifacts({
    required this.rawFrameJpeg,
    required this.guideCropJpeg,
    required this.modelInputJpeg,
    required this.frameWidth,
    required this.frameHeight,
    required this.modelWidth,
    required this.modelHeight,
    required this.cropLeft,
    required this.cropTop,
    required this.cropWidth,
    required this.cropHeight,
  });

  final Uint8List rawFrameJpeg;
  final Uint8List guideCropJpeg;
  final Uint8List modelInputJpeg;
  final int frameWidth;
  final int frameHeight;
  final int modelWidth;
  final int modelHeight;
  final int cropLeft;
  final int cropTop;
  final int cropWidth;
  final int cropHeight;
}

class QualityInferenceResult {
  const QualityInferenceResult({
    required this.probabilities,
    this.debugArtifacts,
  });

  final List<double> probabilities;
  final QualityDebugArtifacts? debugArtifacts;
}

class QualityIsolate {
  QualityIsolate({required this.assetPath});

  final String assetPath;
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _sendPort;
  Isolate? _isolate;
  int _nextId = 0;
  final Map<int, Completer<QualityInferenceResult>> _pending = {};
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
            'layout=${meta['layout']}, '
            'inputShape=${meta['inputShape']}, '
            'outputShape=${meta['outputShape']}',
          );
          return;
        }
        final id = message['id'] as int?;
        final probs = message['probs'] as List<double>?;
        final debug = message['debug'] as Map?;
        final error = message['error'] as String?;
        if (id != null && probs != null) {
          _pending.remove(id)?.complete(
                QualityInferenceResult(
                  probabilities: probs,
                  debugArtifacts: _readDebugArtifacts(debug),
                ),
              );
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
    final contractJson =
        await rootBundle.loadString(AppAssets.docQualityContract);
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
        contractJson,
      ),
    );
    _sendPort = await ready.future;
    completer.complete();
  }

  Future<QualityInferenceResult?> predict(
    CameraImage image, {
    bool includeDebugArtifacts = false,
  }) async {
    final payload = _FramePayload.fromCameraImage(image);
    return predictPayload(
      payload.toMap(),
      includeDebugArtifacts: includeDebugArtifacts,
    );
  }

  Map<String, Object?> buildPayload(CameraImage image) {
    return _FramePayload.fromCameraImage(image).toMap();
  }

  Future<QualityInferenceResult?> predictPayload(
    Map<String, Object?> payload, {
    bool includeDebugArtifacts = false,
  }) async {
    if (_sendPort == null) {
      throw StateError('QualityIsolate not started');
    }
    final id = _nextId++;
    final completer = Completer<QualityInferenceResult>();
    _pending[id] = completer;

    _sendPort!.send({
      'id': id,
      'payload': payload,
      'includeDebug': includeDebugArtifacts,
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

  QualityDebugArtifacts? _readDebugArtifacts(Map? debug) {
    if (debug == null) return null;
    final rawFrame = debug['rawFrameJpg'];
    final guideCrop = debug['guideCropJpg'];
    final modelInput = debug['modelInputJpg'];
    if (rawFrame is! TransferableTypedData ||
        guideCrop is! TransferableTypedData ||
        modelInput is! TransferableTypedData) {
      return null;
    }
    return QualityDebugArtifacts(
      rawFrameJpeg: rawFrame.materialize().asUint8List(),
      guideCropJpeg: guideCrop.materialize().asUint8List(),
      modelInputJpeg: modelInput.materialize().asUint8List(),
      frameWidth: debug['frameWidth'] as int? ?? 0,
      frameHeight: debug['frameHeight'] as int? ?? 0,
      modelWidth: debug['modelWidth'] as int? ?? 0,
      modelHeight: debug['modelHeight'] as int? ?? 0,
      cropLeft: debug['cropLeft'] as int? ?? 0,
      cropTop: debug['cropTop'] as int? ?? 0,
      cropWidth: debug['cropWidth'] as int? ?? 0,
      cropHeight: debug['cropHeight'] as int? ?? 0,
    );
  }
}

class _IsolateConfig {
  _IsolateConfig(
    this.sendPort,
    this.rootToken,
    this.modelData,
    this.contractJson,
  );

  final SendPort sendPort;
  final RootIsolateToken rootToken;
  final TransferableTypedData modelData;
  final String contractJson;
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

Map<String, Object?> augmentQualityPayloadWithGuideConfig(
  Map<String, Object?> payload, {
  required double guideWidthFactor,
  required double guideAspectRatio,
  required double guideMaxHeightFactor,
  required double qualityCropScale,
  int rotationDegrees = 0,
}) {
  return {
    ...payload,
    'guideWidthFactor': guideWidthFactor,
    'guideAspectRatio': guideAspectRatio,
    'guideMaxHeightFactor': guideMaxHeightFactor,
    'qualityCropScale': qualityCropScale,
    'rotationDegrees': rotationDegrees,
  };
}

Future<void> _entry(_IsolateConfig config) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(config.rootToken);
  final receivePort = ReceivePort();
  config.sendPort.send(receivePort.sendPort);

  final contract = DocumentQualityContract.fromJsonString(config.contractJson);
  final modelBytes = config.modelData.materialize().asUint8List();
  final interpreter = Interpreter.fromBuffer(
    modelBytes,
    options: InterpreterOptions()..threads = 2,
  );
  contract.validateInterpreter(interpreter);

  final inputShape = interpreter.getInputTensor(0).shape;
  final outputShape = interpreter.getOutputTensor(0).shape;
  final inputHeight = contract.inputHeight;
  final inputWidth = contract.inputWidth;

  var metaSent = false;
  receivePort.listen((message) {
    if (message is! Map) return;
    final id = message['id'] as int?;
    final payloadMap = message['payload'];
    final includeDebug = message['includeDebug'] == true;
    if (id == null || payloadMap is! Map) return;

    try {
      final payload = _FramePayload.fromMap(payloadMap);
      final guideWidthFactor =
          (payloadMap['guideWidthFactor'] as num?)?.toDouble() ??
              ImageUtils.documentGuideWidthFactor;
      final guideAspectRatio =
          (payloadMap['guideAspectRatio'] as num?)?.toDouble() ??
              ImageUtils.documentGuideAspectRatio;
      final guideMaxHeightFactor =
          (payloadMap['guideMaxHeightFactor'] as num?)?.toDouble() ??
              ImageUtils.documentGuideMaxHeightFactor;
      final qualityCropScale =
          (payloadMap['qualityCropScale'] as num?)?.toDouble() ??
              ImageUtils.documentQualityCropScale;
      final rotationDegrees =
          (payloadMap['rotationDegrees'] as num?)?.toInt() ?? 0;
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
            'layout': contract.layout.name,
            'inputShape': inputShape,
            'outputShape': outputShape,
            'guideWidthFactor': guideWidthFactor,
            'guideAspectRatio': guideAspectRatio,
            'guideMaxHeightFactor': guideMaxHeightFactor,
            'qualityCropScale': qualityCropScale,
            'rotationDegrees': rotationDegrees,
          },
        });
      }
      final image = _applyRotation(
        _imageFromPayload(payload),
        rotationDegrees: rotationDegrees,
      );
      final guideRect = ImageUtils.centeredGuideCropRect(
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        scale: qualityCropScale,
        guideWidthFactor: guideWidthFactor,
        guideAspectRatio: guideAspectRatio,
        guideMaxHeightFactor: guideMaxHeightFactor,
      );
      final cropped = _cropImageToRect(image, guideRect);
      final resized = img.copyResize(
        cropped.image,
        width: inputWidth,
        height: inputHeight,
      );
      final input = _imageToTensor(
        resized,
        contract: contract,
      );
      final output = _createOutputBuffer(outputShape);
      interpreter.run(input, output);
      final probs = _flattenOutput(output);

      config.sendPort.send({
        'id': id,
        'probs': probs,
        if (includeDebug)
          'debug': {
            'rawFrameJpg': TransferableTypedData.fromList([
              Uint8List.fromList(img.encodeJpg(image, quality: 90)),
            ]),
            'guideCropJpg': TransferableTypedData.fromList([
              Uint8List.fromList(img.encodeJpg(cropped.image, quality: 90)),
            ]),
            'modelInputJpg': TransferableTypedData.fromList([
              Uint8List.fromList(img.encodeJpg(resized, quality: 90)),
            ]),
            'frameWidth': image.width,
            'frameHeight': image.height,
            'modelWidth': inputWidth,
            'modelHeight': inputHeight,
            'cropLeft': cropped.left,
            'cropTop': cropped.top,
            'cropWidth': cropped.image.width,
            'cropHeight': cropped.image.height,
          },
      });
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

img.Image _applyRotation(
  img.Image image, {
  required int rotationDegrees,
}) {
  final normalizedRotation = ((rotationDegrees % 360) + 360) % 360;
  if (normalizedRotation == 0) return image;
  return img.copyRotate(image, angle: normalizedRotation);
}

_CroppedQualityImage _cropImageToRect(img.Image source, Rect cropRect) {
  final left = cropRect.left.floor().clamp(0, source.width - 1);
  final top = cropRect.top.floor().clamp(0, source.height - 1);
  final right = cropRect.right.ceil().clamp(left + 1, source.width);
  final bottom = cropRect.bottom.ceil().clamp(top + 1, source.height);

  return _CroppedQualityImage(
    image: img.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    ),
    left: left,
    top: top,
  );
}

class _CroppedQualityImage {
  const _CroppedQualityImage({
    required this.image,
    required this.left,
    required this.top,
  });

  final img.Image image;
  final int left;
  final int top;
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
    final yRow = y * payload.plane0RowStride;
    final uvRow = (y >> 1) * uvRowStride;
    for (int x = 0; x < payload.width; x++) {
      final yp = yBytes[yRow + x];
      final uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final up = uBytes[uvIndex];
      final vp = vBytes[uvIndex];

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
    final row = y * rowStride;
    for (int x = 0; x < payload.width; x++) {
      final offset = row + x * pixelStride;
      final b = bgraBytes[offset];
      final g = bgraBytes[offset + 1];
      final r = bgraBytes[offset + 2];
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

Object _imageToTensor(
  img.Image image, {
  required DocumentQualityContract contract,
}) {
  final rgb = List.generate(
    contract.inputHeight,
    (y) => List.generate(contract.inputWidth, (x) {
      final pixel = image.getPixel(x, y);
      return [
        ((pixel.r * contract.normalization.scale) -
                contract.normalization.mean[0]) /
            contract.normalization.std[0],
        ((pixel.g * contract.normalization.scale) -
                contract.normalization.mean[1]) /
            contract.normalization.std[1],
        ((pixel.b * contract.normalization.scale) -
                contract.normalization.mean[2]) /
            contract.normalization.std[2],
      ];
    }),
  );

  if (contract.layout == ModelTensorLayout.nchw) {
    return [
      List.generate(
        contract.inputChannels,
        (channel) => List.generate(
          contract.inputHeight,
          (y) => List.generate(contract.inputWidth, (x) => rgb[y][x][channel]),
        ),
      ),
    ];
  }

  return [rgb];
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

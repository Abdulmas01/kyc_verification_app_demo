import 'package:kyc_verification_app_demo/core/ml/quality_model.dart';

import '../../domain/models/document_quality_guidance_request.dart';

class DocumentQualityGuidanceEvaluation {
  const DocumentQualityGuidanceEvaluation({
    required this.guidanceQuality,
    required this.pendingQuality,
    required this.pendingCount,
    required this.message,
    required this.allowsQualityAcceptance,
    required this.autoCaptureReady,
    required this.guidanceChanged,
    required this.rawChanged,
    required this.shouldLogHold,
    required this.activeQuality,
  });

  final DocumentQuality guidanceQuality;
  final DocumentQuality? pendingQuality;
  final int pendingCount;
  final String message;
  final bool allowsQualityAcceptance;
  final bool autoCaptureReady;
  final bool guidanceChanged;
  final bool rawChanged;
  final bool shouldLogHold;
  final DocumentQuality? activeQuality;
}

class DocumentQualityGuidanceService {
  DocumentQuality? _pendingGuidanceQuality;
  int _pendingGuidanceCount = 0;
  DocumentQuality? _activeGuidanceQuality;
  DocumentQuality? _lastLoggedRawQuality;
  DocumentQuality? _lastLoggedGuidanceQuality;
  String? _lastGuidanceMessage;
  bool _lastGuidanceHoldLogged = false;

  static const double strongNegativeGuidanceThreshold = 0.50;
  static const double strongNegativeImmediateThreshold = 0.65;

  DocumentQuality? get pendingGuidanceQuality => _pendingGuidanceQuality;
  int get pendingGuidanceCount => _pendingGuidanceCount;
  DocumentQuality? get activeGuidanceQuality => _activeGuidanceQuality;
  DocumentQuality? get lastLoggedRawQuality => _lastLoggedRawQuality;
  DocumentQuality? get lastLoggedGuidanceQuality => _lastLoggedGuidanceQuality;
  String? get lastGuidanceMessage => _lastGuidanceMessage;

  void reset() {
    _pendingGuidanceQuality = null;
    _pendingGuidanceCount = 0;
    _activeGuidanceQuality = null;
    _lastLoggedRawQuality = null;
    _lastLoggedGuidanceQuality = null;
    _lastGuidanceMessage = null;
    _lastGuidanceHoldLogged = false;
  }

  DocumentQualityGuidanceEvaluation evaluate(
    DocumentQualityGuidanceRequest request,
  ) {
    final quality = request.quality;
    final config = request.config;
    final usesQualityGate = request.usesQualityGate;
    final guidanceQuality = _resolveGuidanceQuality(
      quality: quality,
      stabilityFrames: config.guidanceStabilityFrames,
    );
    final message = _messageForQuality(guidanceQuality);
    final allowsQualityAcceptance = !usesQualityGate || quality.isGood;
    final autoCaptureReady =
        guidanceQuality == DocumentQuality.good && quality.isGood;
    final rawChanged = quality.quality != _lastLoggedRawQuality;
    final guidanceChanged = guidanceQuality != _lastLoggedGuidanceQuality ||
        message != _lastGuidanceMessage;

    return DocumentQualityGuidanceEvaluation(
      guidanceQuality: guidanceQuality,
      pendingQuality: _pendingGuidanceQuality,
      pendingCount: _pendingGuidanceCount,
      message: message,
      allowsQualityAcceptance: allowsQualityAcceptance,
      autoCaptureReady: autoCaptureReady,
      guidanceChanged: guidanceChanged,
      rawChanged: rawChanged,
      shouldLogHold: _lastGuidanceHoldLogged,
      activeQuality: _activeGuidanceQuality,
    );
  }

  void markTransitionLogged({
    required QualityResult quality,
    required DocumentQuality guidanceQuality,
    required String guidanceMessage,
  }) {
    _lastLoggedRawQuality = quality.quality;
    _lastLoggedGuidanceQuality = guidanceQuality;
    _lastGuidanceMessage = guidanceMessage;
    _lastGuidanceHoldLogged = false;
  }

  void markHoldLogged() {
    _lastGuidanceHoldLogged = true;
  }

  DocumentQuality _resolveGuidanceQuality({
    required QualityResult quality,
    required int stabilityFrames,
  }) {
    final nextQuality = quality.guidanceQuality;
    if (_activeGuidanceQuality == null) {
      _activeGuidanceQuality = nextQuality;
      _pendingGuidanceQuality = null;
      _pendingGuidanceCount = 0;
      _lastGuidanceHoldLogged = false;
      return nextQuality;
    }

    if (nextQuality == _activeGuidanceQuality) {
      _pendingGuidanceQuality = null;
      _pendingGuidanceCount = 0;
      _lastGuidanceHoldLogged = false;
      return _activeGuidanceQuality!;
    }

    if (_shouldImmediatelySwitchGuidance(quality, nextQuality)) {
      _activeGuidanceQuality = nextQuality;
      _pendingGuidanceQuality = null;
      _pendingGuidanceCount = 0;
      _lastGuidanceHoldLogged = false;
      return nextQuality;
    }

    if (_pendingGuidanceQuality != nextQuality) {
      _pendingGuidanceQuality = nextQuality;
      _pendingGuidanceCount = 1;
      return _activeGuidanceQuality!;
    }

    _pendingGuidanceCount++;
    if (_pendingGuidanceCount < stabilityFrames) {
      return _activeGuidanceQuality!;
    }

    _activeGuidanceQuality = nextQuality;
    _pendingGuidanceQuality = null;
    _pendingGuidanceCount = 0;
    _lastGuidanceHoldLogged = false;
    return nextQuality;
  }

  bool _shouldImmediatelySwitchGuidance(
    QualityResult quality,
    DocumentQuality nextQuality,
  ) {
    if (_activeGuidanceQuality == DocumentQuality.good &&
        nextQuality != DocumentQuality.good) {
      return quality.confidence >= strongNegativeGuidanceThreshold;
    }

    if (_activeGuidanceQuality != null &&
        _activeGuidanceQuality != nextQuality &&
        nextQuality != DocumentQuality.noDocument &&
        quality.confidence >= strongNegativeImmediateThreshold) {
      return true;
    }

    return false;
  }

  String _messageForQuality(DocumentQuality quality) {
    switch (quality) {
      case DocumentQuality.good:
        return 'Hold steady for capture.';
      case DocumentQuality.blurry:
        return 'Hold still for a clearer capture.';
      case DocumentQuality.glare:
        return 'Tilt slightly to reduce glare.';
      case DocumentQuality.dark:
        return 'Move to better lighting.';
      case DocumentQuality.noDocument:
        return 'Place your ID fully inside the frame.';
    }
  }
}


import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../services/database_service.dart';
import 'score_page.dart';

enum ShotPhase { idle, set, dip, rise, release, complete }

class PosePainter extends CustomPainter {
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final Size imageSize;

  PosePainter({
    required this.landmarks,
    required this.imageSize,
  });

  static const List<List<PoseLandmarkType>> connections = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  Offset? _scale(PoseLandmarkType type, Size canvasSize) {
    final lm = landmarks[type];
    if (lm == null) return null;

    final safeW = imageSize.width <= 0 ? 1.0 : imageSize.width;
    final safeH = imageSize.height <= 0 ? 1.0 : imageSize.height;

    final scaleX = canvasSize.width / safeW;
    final scaleY = canvasSize.height / safeH;

    // Front camera preview is mirrored; mirror overlay horizontally to match.
    final mirroredX = safeW - lm.x;

    return Offset(
      mirroredX * scaleX,
      lm.y * scaleY,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 2;

    final jointPaint = Paint()..color = Colors.greenAccent;

    for (final pair in connections) {
      final a = _scale(pair[0], size);
      final b = _scale(pair[1], size);
      if (a != null && b != null) {
        canvas.drawLine(a, b, linePaint);
      }
    }

    for (final entry in landmarks.entries) {
      final p = _scale(entry.key, size);
      if (p != null) {
        canvas.drawCircle(p, 4, jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks || oldDelegate.imageSize != imageSize;
  }
}

class BodyTrackingPage extends StatefulWidget {
  const BodyTrackingPage({super.key});

  @override
  State<BodyTrackingPage> createState() => _BodyTrackingPageState();
}

class _BodyTrackingPageState extends State<BodyTrackingPage> {
  // =====================
  // Scoring configuration
  // =====================

  static const double _kneeGoodMin = 71.0;
  static const double _kneeGoodMax = 101.0;

  static const double _elbowGoodMin = 165.0;
  static const double _elbowGoodMax = 180.0;

  // (elbow.y - wrist.y) / torsoLen
  static const double _wristLiftGoodMin = 0.10;
  static const double _wristLiftGoodMax = 0.18;

  // deg/ms (dt is ms)
  static const double _speedGoodMin = 0.06;
  static const double _speedGoodMax = 0.20;

  int _scoreRange25(double value, double minV, double maxV) {
    if (!value.isFinite) return 0;
    if (value <= minV) return 0;
    if (value >= maxV) return 25;
    final t = (value - minV) / (maxV - minV);
    return (t * 25).round();
  }

  int _scoreBand25(
    double value,
    double goodMin,
    double goodMax, {
    double falloff = 40,
  }) {
    if (!value.isFinite) return 0;

    if (value >= goodMin && value <= goodMax) return 25;

    if (value < goodMin) {
      final diff = goodMin - value;
      return (25 - (diff / falloff) * 25).clamp(0, 25).round();
    } else {
      final diff = value - goodMax;
      return (25 - (diff / falloff) * 25).clamp(0, 25).round();
    }
  }

  // =====================
  // Detection tuning
  // =====================

  // Smoothing for angles to reduce noisy ROM/velocity spikes
  // Higher alpha = more responsive, lower alpha = smoother
  static const double _emaAlpha = 0.35;

  // Prevent “upright false releases”: require elbow to be fairly extended when we call release
  static const double _minElbowAtRelease = 150.0;

  // Debounce: release gate must pass N consecutive frames
  static const int _releaseConfirmFrames = 2;
  int _releaseCandidateCount = 0;

  // ROM thresholds (degrees). Keep your strict-ish values, but with smoothing + debounce.
  static const double _minKneeROM = 20.0;
  static const double _minElbowROM = 20.0;

  // Velocity threshold (deg/ms) for elbow extension
  static const double _minElbowVel = 0.02;

  // =====================
  // State
  // =====================
  ShotPhase _phase = ShotPhase.idle;

  bool _wristAboveShoulderSeen = false;

  double _minElbowAngle = 999;
  double _maxElbowAngle = 0;
  bool _armLoaded = false;

  double _maxKneeAngle = 0;
  double _minKneeAngle = 999;

  bool _dipDetected = false;
  bool _riseDetected = false;

  CameraController? _controller;
  late final PoseDetector _poseDetector;

  bool _isStreaming = false;
  bool _isProcessing = false;
  bool _autoStopping = false;
  bool _showLoading = false;

  Timer? _autoStopTimer;

  double _latestElbowAngle = 0;
  double _latestKneeAngle = 0;

  // EMA smoothed angles (for detection/velocity)
  double? _smoothedElbow;
  double? _smoothedKnee;

  // Release snapshot
  double? _releaseElbow;
  double? _releaseKnee;
  int? _releaseTimeMs;
  Map<PoseLandmarkType, PoseLandmark>? _releaseLandmarks;

  // Peak elbow speed at release (deg/ms)
  double _elbowSpeedAtRelease = 0;

  // ✅ Wrist follow-through tracking: max normalized lift over the rep
  double _maxWristLiftNorm = 0;

  Map<PoseLandmarkType, PoseLandmark> _latestLandmarks = {};
  Size _latestImageSize = const Size(1, 1);

  final DatabaseService _db = DatabaseService();

  // Throttle iOS
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minProcessIntervalMs = 120; // ~8 fps

  final List<_AngleSample> _angleHistory = [];
  bool _releaseDetected = false;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startStreaming() async {
    if (_isStreaming) return;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Reset per-rep
    _angleHistory.clear();
    _releaseDetected = false;
    _autoStopping = false;
    _showLoading = false;

    _releaseElbow = null;
    _releaseKnee = null;
    _releaseTimeMs = null;
    _releaseLandmarks = null;

    _elbowSpeedAtRelease = 0;

    _phase = ShotPhase.idle;

    _maxKneeAngle = 0;
    _minKneeAngle = 999;
    _maxElbowAngle = 0;
    _minElbowAngle = 999;

    _dipDetected = false;
    _riseDetected = false;

    _armLoaded = false;
    _wristAboveShoulderSeen = false;

    _releaseCandidateCount = 0;

    _smoothedElbow = null;
    _smoothedKnee = null;

    _maxWristLiftNorm = 0;

    _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

    await controller.startImageStream((CameraImage image) async {
      final now = DateTime.now();
      if (now.difference(_lastProcessed).inMilliseconds < _minProcessIntervalMs) return;
      _lastProcessed = now;

      if (_isProcessing || _autoStopping) return;
      _isProcessing = true;

      try {
        _latestImageSize = Size(image.width.toDouble(), image.height.toDouble());

        final inputImage = _convertCameraImage(image, controller.description);
        final poses = await _poseDetector.processImage(inputImage);

        if (poses.isNotEmpty) {
          _processPose(poses.first, now);
        }
      } finally {
        _isProcessing = false;
      }
    });

    if (mounted) setState(() => _isStreaming = true);
  }

  void _processPose(Pose pose, DateTime timestamp) {
    _latestLandmarks = Map<PoseLandmarkType, PoseLandmark>.from(pose.landmarks);

    final shoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final wrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final hip = pose.landmarks[PoseLandmarkType.rightHip];
    final knee = pose.landmarks[PoseLandmarkType.rightKnee];
    final ankle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Gate: wrist must rise above shoulder at least once
    if (shoulder != null && wrist != null) {
      if (wrist.y < shoulder.y) _wristAboveShoulderSeen = true;
    }

    // ✅ Track max wrist lift over the whole rep (normalized)
    if (shoulder != null && hip != null && elbow != null && wrist != null) {
      final torsoLen = sqrt(pow(shoulder.x - hip.x, 2) + pow(shoulder.y - hip.y, 2));
      if (torsoLen > 1e-6) {
        final liftNorm = (elbow.y - wrist.y) / torsoLen; // + if wrist above elbow
        if (liftNorm.isFinite) {
          _maxWristLiftNorm = max(_maxWristLiftNorm, liftNorm);
        }
      }
    }

    double? elbowAngleRaw;
    double? kneeAngleRaw;

    if (shoulder != null && elbow != null && wrist != null) {
      elbowAngleRaw = _calculateAngle(shoulder, elbow, wrist);
    }

    if (hip != null && knee != null && ankle != null) {
      kneeAngleRaw = _calculateAngle(hip, knee, ankle);
    }

    if (elbowAngleRaw != null && kneeAngleRaw != null) {
      // EMA smoothing
      _smoothedElbow = _ema(_smoothedElbow, elbowAngleRaw, _emaAlpha);
      _smoothedKnee = _ema(_smoothedKnee, kneeAngleRaw, _emaAlpha);

      final elbowAngle = _smoothedElbow!;
      final kneeAngle = _smoothedKnee!;

      // Update UI angles from smoothed (more stable readout)
      _latestElbowAngle = elbowAngle;
      _latestKneeAngle = kneeAngle;

      _angleHistory.add(
        _AngleSample(
          t: timestamp.millisecondsSinceEpoch,
          elbow: elbowAngle,
          knee: kneeAngle,
        ),
      );

      if (_angleHistory.length > 180) {
        _angleHistory.removeAt(0);
      }

      if (!_releaseDetected) {
        _updateShotPhase();
      }
    }

    if (mounted) setState(() {});
  }

  double _ema(double? prev, double next, double alpha) {
    if (prev == null) return next;
    return prev + alpha * (next - prev);
  }

  void _updateShotPhase() {
    if (_angleHistory.length < 6) return;

    final w = _angleHistory.sublist(_angleHistory.length - 6);

    double kneeVel(_AngleSample a0, _AngleSample a1) {
      final dt = max(1, a1.t - a0.t);
      return (a1.knee - a0.knee) / dt;
    }

    double elbowVel(_AngleSample a0, _AngleSample a1) {
      final dt = max(1, a1.t - a0.t);
      return (a1.elbow - a0.elbow) / dt;
    }

    final current = w.last;
    final prev = w[w.length - 2];

    final kneeVelocity = kneeVel(prev, current);
    final elbowVelocity = elbowVel(prev, current);

    // Track ROM (smoothed)
    _maxKneeAngle = max(_maxKneeAngle, current.knee);
    _minKneeAngle = min(_minKneeAngle, current.knee);

    _maxElbowAngle = max(_maxElbowAngle, current.elbow);
    _minElbowAngle = min(_minElbowAngle, current.elbow);

    final kneeROM = _maxKneeAngle - _minKneeAngle;
    final elbowROM = _maxElbowAngle - _minElbowAngle;

    // Arm "loaded" = elbow flexed significantly at some point
    if (_minElbowAngle < 130) _armLoaded = true;

    switch (_phase) {
      case ShotPhase.idle:
        if (kneeVelocity.abs() < 0.01) {
          _phase = ShotPhase.set;
        }
        break;

      case ShotPhase.set:
        if (kneeVelocity < -0.01) {
          _phase = ShotPhase.dip;
          _dipDetected = true;
        }
        break;

      case ShotPhase.dip:
        if (kneeVelocity > 0.01) {
          _phase = ShotPhase.rise;
          _riseDetected = true;
        }
        break;

      case ShotPhase.rise:
        // Main release gate (same spirit as your last working point),
        // but with:
        //  - EMA smoothing (reduces noise)
        //  - min elbow angle at release
        //  - debounce over 2 frames
        final gatePass = _dipDetected &&
            _riseDetected &&
            _wristAboveShoulderSeen &&
            _armLoaded &&
            kneeROM >= _minKneeROM &&
            elbowROM >= _minElbowROM &&
            elbowVelocity > _minElbowVel &&
            current.elbow >= _minElbowAtRelease;

        if (gatePass) {
          _releaseCandidateCount++;
        } else {
          _releaseCandidateCount = 0;
        }

        if (_releaseCandidateCount >= _releaseConfirmFrames) {
          _phase = ShotPhase.release;

          _releaseDetected = true;
          _releaseElbow = current.elbow;
          _releaseKnee = current.knee;
          _releaseTimeMs = current.t;

          _releaseLandmarks = Map<PoseLandmarkType, PoseLandmark>.from(_latestLandmarks);

          _elbowSpeedAtRelease = _peakElbowVelocity(window: 6);

          _handleAutoStop();
        }
        break;

      case ShotPhase.release:
        _phase = ShotPhase.complete;
        break;

      case ShotPhase.complete:
        break;
    }
  }

  double _peakElbowVelocity({int window = 6}) {
    if (_angleHistory.length < 3) return 0;

    final start = max(0, _angleHistory.length - window);
    final w = _angleHistory.sublist(start);

    double peak = 0;
    for (int i = 1; i < w.length; i++) {
      final dt = max(1, w[i].t - w[i - 1].t); // ms
      final v = (w[i].elbow - w[i - 1].elbow) / dt; // deg/ms
      if (v > peak) peak = v;
    }
    return peak;
  }

  Future<void> _handleAutoStop() async {
    if (_autoStopping) return;
    _autoStopping = true;

    if (mounted) {
      setState(() => _showLoading = true);
    }

    _autoStopTimer?.cancel();

    _autoStopTimer = Timer(const Duration(milliseconds: 250), () async {
      await _stopStreaming();

      final breakdown = _computeScoreBreakdown();

      final shot = ShotRecord(
        elbowAngle: _releaseElbow ?? 0,
        kneeAngle: _releaseKnee ?? 0,
        totalScore: breakdown.totalScore,
        elbowScore: breakdown.elbowScore,
        kneeScore: breakdown.kneeScore,
        wristScore: breakdown.wristScore,
        speedScore: breakdown.speedScore,
        releaseTimeMs: _releaseTimeMs ?? 0,
        timestamp: DateTime.now().toIso8601String(),
      );

      await _db.insertShot(shot);

      if (!mounted) return;

      setState(() => _showLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScorePage(
            totalScore: breakdown.totalScore,
            elbowScore: breakdown.elbowScore,
            kneeScore: breakdown.kneeScore,
            wristScore: breakdown.wristScore,
            speedScore: breakdown.speedScore,
            elbow: _releaseElbow ?? 0,
            knee: _releaseKnee ?? 0,
          ),
        ),
      );
    });
  }

  Future<void> _stopStreaming() async {
    final controller = _controller;
    if (controller == null) return;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }

    if (mounted) {
      setState(() => _isStreaming = false);
    }

    _autoStopping = false;
  }

  _ScoreBreakdown _computeScoreBreakdown() {
    // 1) Knee dip depth score (min knee angle during rep)
    double minKnee = _releaseKnee ?? _latestKneeAngle;
    if (_angleHistory.isNotEmpty) {
      minKnee = _angleHistory.map((e) => e.knee).reduce((a, b) => a < b ? a : b);
    }

    final kneeScore = _scoreBand25(
      minKnee,
      _kneeGoodMin,
      _kneeGoodMax,
      falloff: 35,
    );

    // 2) Elbow extension score (at release)
    final elbowAtRelease = _releaseElbow ?? _latestElbowAngle;
    final elbowScore = _scoreBand25(
      elbowAtRelease,
      _elbowGoodMin,
      _elbowGoodMax,
      falloff: 25,
    );

    // ✅ 3) Wrist follow-through score (use MAX over rep, not snapshot)
    // This fixes the “regression” you saw when wrist at the exact release frame is noisy/occluded.
    int wristScore = _scoreRange25(_maxWristLiftNorm, _wristLiftGoodMin, _wristLiftGoodMax);

    // If wrist never went above shoulder, heavily discount (but don't hard cap to 5)
    if (!_wristAboveShoulderSeen) {
      wristScore = (wristScore * 0.5).round();
    }

    // 4) Speed score (peak elbow angular velocity near release)
    final speedScore = _scoreRange25(_elbowSpeedAtRelease, _speedGoodMin, _speedGoodMax);

    final total = (kneeScore + elbowScore + wristScore + speedScore).clamp(0, 100);

    return _ScoreBreakdown(
      totalScore: total,
      elbowScore: elbowScore,
      kneeScore: kneeScore,
      wristScore: wristScore,
      speedScore: speedScore,
    );
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ab = Offset(a.x - b.x, a.y - b.y);
    final cb = Offset(c.x - b.x, c.y - b.y);

    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final magAB = ab.distance;
    final magCB = cb.distance;

    if (magAB == 0 || magCB == 0) return 0;

    final cosTheta = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return acos(cosTheta) * 180 / pi;
  }

  InputImage _convertCameraImage(CameraImage image, CameraDescription camera) {
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();

    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      controller.stopImageStream();
    }

    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Free Throw Analysis")),
      body: Stack(
        children: [
          CameraPreview(controller),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PosePainter(
                  landmarks: _latestLandmarks,
                  imageSize: _latestImageSize,
                ),
              ),
            ),
          ),

          if (_showLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Analyzing Shot...", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 40,
            left: 10,
            child: ElevatedButton(
              onPressed: _isStreaming ? _stopStreaming : _startStreaming,
              child: Text(_isStreaming ? "Stop Recording" : "Start Recording"),
            ),
          ),

          // Debug overlay
          Positioned(
            bottom: 110,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Phase: $_phase", style: const TextStyle(color: Colors.white)),
                  Text("Elbow: ${_latestElbowAngle.toStringAsFixed(1)}°",
                      style: const TextStyle(color: Colors.white)),
                  Text("Knee: ${_latestKneeAngle.toStringAsFixed(1)}°",
                      style: const TextStyle(color: Colors.white)),
                  Text("ArmLoaded: $_armLoaded  WristUp: $_wristAboveShoulderSeen",
                      style: const TextStyle(color: Colors.white)),
                  Text("WristLiftMax: ${_maxWristLiftNorm.toStringAsFixed(3)}",
                      style: const TextStyle(color: Colors.white)),
                  Text("ElbowSpeedPeak: ${_elbowSpeedAtRelease.toStringAsFixed(3)} deg/ms",
                      style: const TextStyle(color: Colors.white)),
                  if (_releaseDetected)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "RELEASE DETECTED",
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AngleSample {
  final int t;
  final double elbow;
  final double knee;

  _AngleSample({
    required this.t,
    required this.elbow,
    required this.knee,
  });
}

class _ScoreBreakdown {
  final int totalScore;
  final int elbowScore;
  final int kneeScore;
  final int wristScore;
  final int speedScore;

  _ScoreBreakdown({
    required this.totalScore,
    required this.elbowScore,
    required this.kneeScore,
    required this.wristScore,
    required this.speedScore,
  });
}
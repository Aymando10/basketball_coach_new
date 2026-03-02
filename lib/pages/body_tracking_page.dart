// body_tracking_page.dart

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
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.imageSize != imageSize;
  }
}

class BodyTrackingPage extends StatefulWidget {
  const BodyTrackingPage({super.key});

  @override
  State<BodyTrackingPage> createState() => _BodyTrackingPageState();
}

class _BodyTrackingPageState extends State<BodyTrackingPage> {
  CameraController? _controller;
  late final PoseDetector _poseDetector;

  bool _isStreaming = false;
  bool _isProcessing = false;
  bool _autoStopping = false;
  bool _showLoading = false;

  Timer? _autoStopTimer;

  double _latestElbowAngle = 0;
  double _latestKneeAngle = 0;

  double? _releaseElbow;
  double? _releaseKnee;
  int? _releaseTimeMs;

  double _kneeSpeedAtRelease = 0;
  double _elbowSpeedAtRelease = 0;

  Map<PoseLandmarkType, PoseLandmark> _latestLandmarks = {};
  Size _latestImageSize = const Size(1, 1);

  final DatabaseService _db = DatabaseService();

  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minProcessIntervalMs = 120;

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

    _angleHistory.clear();
    _releaseDetected = false;
    _autoStopping = false;

    _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

    await controller.startImageStream((CameraImage image) async {
      final now = DateTime.now();
      if (now.difference(_lastProcessed).inMilliseconds <
          _minProcessIntervalMs) return;

      _lastProcessed = now;

      if (_isProcessing || _autoStopping) return;
      _isProcessing = true;

      try {
        _latestImageSize =
            Size(image.width.toDouble(), image.height.toDouble());

        final inputImage =
            _convertCameraImage(image, controller.description);

        final poses =
            await _poseDetector.processImage(inputImage);

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
    _latestLandmarks =
        Map<PoseLandmarkType, PoseLandmark>.from(pose.landmarks);

    final shoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final wrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final hip = pose.landmarks[PoseLandmarkType.rightHip];
    final knee = pose.landmarks[PoseLandmarkType.rightKnee];
    final ankle = pose.landmarks[PoseLandmarkType.rightAnkle];

    double? elbowAngle;
    double? kneeAngle;

    if (shoulder != null && elbow != null && wrist != null) {
      elbowAngle = _calculateAngle(shoulder, elbow, wrist);
      _latestElbowAngle = elbowAngle;
    }

    if (hip != null && knee != null && ankle != null) {
      kneeAngle = _calculateAngle(hip, knee, ankle);
      _latestKneeAngle = kneeAngle;
    }

    if (elbowAngle != null && kneeAngle != null) {
      _angleHistory.add(
        _AngleSample(
          t: timestamp.millisecondsSinceEpoch,
          elbow: elbowAngle,
          knee: kneeAngle,
        ),
      );

      if (_angleHistory.length > 150) {
        _angleHistory.removeAt(0);
      }

      if (!_releaseDetected) {
        _tryDetectRelease();
      }
    }

    if (mounted) setState(() {});
  }

  void _tryDetectRelease() {
    if (_angleHistory.length < 6) return;

    final w = _angleHistory.sublist(_angleHistory.length - 6);

    double vel(_AngleSample a0, _AngleSample a1) {
      final dt = max(1, a1.t - a0.t);
      return (a1.elbow - a0.elbow) / dt;
    }

    double kneeVel(_AngleSample a0, _AngleSample a1) {
      final dt = max(1, a1.t - a0.t);
      return (a1.knee - a0.knee) / dt;
    }

    final v1 = vel(w[2], w[3]);
    final v2 = vel(w[3], w[4]);
    final v3 = vel(w[4], w[5]);

    final kneeExtending =
        kneeVel(w[3], w[4]) > 0 &&
        kneeVel(w[4], w[5]) > 0;

    final elbowSpike =
        v3 > v2 &&
        v3 > v1 &&
        v3 > 0.02;

    if (kneeExtending && elbowSpike) {
      _releaseDetected = true;

      final releaseSample = w.last;

      _releaseElbow = releaseSample.elbow;
      _releaseKnee = releaseSample.knee;
      _releaseTimeMs = releaseSample.t;

      _kneeSpeedAtRelease = kneeVel(w[4], w[5]);
      _elbowSpeedAtRelease = vel(w[4], w[5]);

      _handleAutoStop();
    }
  }

  Future<void> _handleAutoStop() async {
    if (_autoStopping) return;
    _autoStopping = true;

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _showLoading = true;
      });
    }

    _autoStopTimer?.cancel();

    _autoStopTimer = Timer(const Duration(milliseconds: 300), () async {
      await _stopStreaming();

      final score = _computeScore();

      final shot = ShotRecord(
        elbowAngle: _releaseElbow ?? 0,
        kneeAngle: _releaseKnee ?? 0,
        score: score,
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
            score: score,
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

    _autoStopping = false;
  }

  int _computeScore() {
    int scoreAngle(
        double value, double target, double tolerance, int maxPoints) {
      final diff = (value - target).abs();
      final raw = (1 - (diff / tolerance)).clamp(0.0, 1.0);
      return (raw * maxPoints).round();
    }

    final elbowScore =
        scoreAngle(_releaseElbow ?? 0, 175, 25, 40);

    final kneeScore =
        scoreAngle(_releaseKnee ?? 0, 170, 30, 40);

    final coordinationScore =
        (_kneeSpeedAtRelease > 0 &&
                _elbowSpeedAtRelease > 0.02)
            ? 20
            : 10;

    return elbowScore + kneeScore + coordinationScore;
  }

  double _calculateAngle(
      PoseLandmark a,
      PoseLandmark b,
      PoseLandmark c) {
    final ab = Offset(a.x - b.x, a.y - b.y);
    final cb = Offset(c.x - b.x, c.y - b.y);

    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final magAB = ab.distance;
    final magCB = cb.distance;

    if (magAB == 0 || magCB == 0) return 0;

    final cosTheta =
        (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return acos(cosTheta) * 180 / pi;
  }

  InputImage _convertCameraImage(
      CameraImage image,
      CameraDescription camera) {
    final rotation =
        InputImageRotationValue.fromRawValue(
                camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(),
            image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow:
            image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();

    final controller = _controller;
    if (controller != null &&
        controller.value.isStreamingImages) {
      controller.stopImageStream();
    }

    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                      CircularProgressIndicator(
                          color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        "Analyzing Shot...",
                        style: TextStyle(color: Colors.white),
                      )
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 40,
            left: 10,
            child: ElevatedButton(
              onPressed: _isStreaming
                  ? _stopStreaming
                  : _startStreaming,
              child: Text(
                _isStreaming
                    ? "Stop Recording"
                    : "Start Recording",
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
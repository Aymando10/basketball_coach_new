import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../services/database_service.dart';

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

    // Avoid divide-by-zero / nonsense sizes
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

    // Connections
    for (final pair in connections) {
      final a = _scale(pair[0], size);
      final b = _scale(pair[1], size);
      if (a != null && b != null) {
        canvas.drawLine(a, b, linePaint);
      }
    }

    // Joints
    for (final entry in landmarks.entries) {
      final p = _scale(entry.key, size);
      if (p != null) {
        canvas.drawCircle(p, 4, jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    // Repaint when new landmark map instance arrives or image size changes
    return oldDelegate.landmarks != landmarks || oldDelegate.imageSize != imageSize;
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

  double _latestElbowAngle = 0;
  double _latestKneeAngle = 0;

  Map<PoseLandmarkType, PoseLandmark> _latestLandmarks = {};
  Size _latestImageSize = const Size(1, 1);

  final DatabaseService _db = DatabaseService();

  // Throttle (important on iOS to avoid UI freeze)
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minProcessIntervalMs = 120; // ~8 fps

  @override
  void initState() {
    super.initState();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
      ),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    // ✅ Always front camera
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // iOS-friendly for MLKit
    );

    _controller = controller;
    await controller.initialize();

    if (mounted) setState(() {});
  }

  Future<void> _startStreaming() async {
    if (_isStreaming) return;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

    await controller.startImageStream((CameraImage image) async {
      // Throttle frames
      final now = DateTime.now();
      if (now.difference(_lastProcessed).inMilliseconds < _minProcessIntervalMs) {
        return;
      }
      _lastProcessed = now;

      if (_isProcessing) return;
      _isProcessing = true;

      try {
        // Update image size for the painter
        _latestImageSize = Size(image.width.toDouble(), image.height.toDouble());

        final inputImage = _convertCameraImage(image, controller.description);
        final poses = await _poseDetector.processImage(inputImage);

        if (poses.isNotEmpty) {
          _processPose(poses.first);
        } else {
          // Optional: clear overlay when nothing detected (comment out if you prefer "last known pose")
          // if (_latestLandmarks.isNotEmpty && mounted) setState(() => _latestLandmarks = {});
        }
      } catch (_) {
        // Optional: debugPrint("Pose processing error: $e");
      } finally {
        _isProcessing = false;
      }
    });

    if (mounted) setState(() => _isStreaming = true);
  }

  Future<void> _stopStreaming() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // ignore
      }
    }

    // Log last measured values
    await _db.insertShot(_latestElbowAngle, _latestKneeAngle);

    if (mounted) setState(() => _isStreaming = false);
  }

  void _processPose(Pose pose) {
    // New map instance so shouldRepaint triggers reliably
    _latestLandmarks = Map<PoseLandmarkType, PoseLandmark>.from(pose.landmarks);

    final shoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final wrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final hip = pose.landmarks[PoseLandmarkType.rightHip];
    final knee = pose.landmarks[PoseLandmarkType.rightKnee];
    final ankle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder != null && elbow != null && wrist != null) {
      _latestElbowAngle = _calculateAngle(shoulder, elbow, wrist);
    }

    if (hip != null && knee != null && ankle != null) {
      _latestKneeAngle = _calculateAngle(hip, knee, ankle);
    }

    if (mounted) setState(() {});
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

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    // NOTE: This "plane[0]" approach is what you've had working on iOS.
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
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      controller.stopImageStream(); // don't await in dispose
    }

    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Free Throw Analysis"),
      ),
      body: Stack(
        children: [
          // 1) Camera preview
          CameraPreview(controller),

          // 2) ✅ Overlay must be forced to fill the Stack, otherwise it may not paint.
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

          // 3) UI
          Positioned(
            bottom: 40,
            left: 10, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Elbow: ${_latestElbowAngle.toStringAsFixed(1)}°",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Knee: ${_latestKneeAngle.toStringAsFixed(1)}°",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                  child: Text(
                    _isStreaming ? "Stop Recording" : "Start Recording",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../services/database_service.dart';

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

  final DatabaseService _db = DatabaseService();

  // ✅ Throttle (critical on iOS to avoid UI freeze)
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

    // iPhone: back camera is fine for now (as you requested)
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // ✅ iOS-friendly for MLKit
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startStreaming() async {
    if (_isStreaming) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Reset last processed time so it starts clean
    _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

    await controller.startImageStream((CameraImage image) async {
      // ✅ Throttle frames
      final now = DateTime.now();
      if (now.difference(_lastProcessed).inMilliseconds < _minProcessIntervalMs) {
        return;
      }
      _lastProcessed = now;

      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final inputImage = _convertCameraImage(image, controller.description);
        final poses = await _poseDetector.processImage(inputImage);

        if (poses.isNotEmpty) {
          _processPose(poses.first);
        }
      } catch (e) {
        // Optional: print("Pose processing error: $e");
      } finally {
        _isProcessing = false;
      }
    });

    if (mounted) setState(() => _isStreaming = true);
  }

  Future<void> _stopStreaming() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}

    // Log last measured values
    await _db.insertShot(_latestElbowAngle, _latestKneeAngle);

    if (mounted) setState(() => _isStreaming = false);
  }

  void _processPose(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final wrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final hip = pose.landmarks[PoseLandmarkType.rightHip];
    final knee = pose.landmarks[PoseLandmarkType.rightKnee];
    final ankle = pose.landmarks[PoseLandmarkType.rightAnkle];

    bool changed = false;

    if (shoulder != null && elbow != null && wrist != null) {
      final newElbow = _calculateAngle(shoulder, elbow, wrist);
      if (newElbow.isFinite) {
        _latestElbowAngle = newElbow;
        changed = true;
      }
    }

    if (hip != null && knee != null && ankle != null) {
      final newKnee = _calculateAngle(hip, knee, ankle);
      if (newKnee.isFinite) {
        _latestKneeAngle = newKnee;
        changed = true;
      }
    }

    // ✅ Only rebuild when we actually computed something new
    if (changed && mounted) {
      setState(() {});
    }
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

    // NOTE: Using plane[0] bytes worked for you, keep it as-is.
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
    // If streaming, stop first (prevents iOS camera deadlocks on dispose)
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Free Throw Analysis")),
      body: Stack(
        children: [
          CameraPreview(controller),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Elbow: ${_latestElbowAngle.toStringAsFixed(1)}°",
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  "Knee: ${_latestKneeAngle.toStringAsFixed(1)}°",
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                  child: Text(_isStreaming ? "Stop Recording" : "Start Recording"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
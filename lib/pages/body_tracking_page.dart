import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

// Custom painter for landmarks
class PosePainter extends CustomPainter {
  final List<Offset> points;
  PosePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 5.0
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point, 5.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BodyTrackingPage extends StatefulWidget {
  const BodyTrackingPage({super.key});

  @override
  State<BodyTrackingPage> createState() => _BodyTrackingPageState();
}

class _BodyTrackingPageState extends State<BodyTrackingPage> {
  CameraController? _controller;
  bool _isDetecting = false;
  List<Offset> _landmarks = [];
  late List<CameraDescription> cameras;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();

    _controller!.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        processCameraImage(image);
      }
    });

    setState(() {});
  }

  Future<void> processCameraImage(CameraImage image) async {
    try {
      // Convert YUV -> JPEG
      final jpeg = await convertYUV420toJpeg(image);

      // Send to backend (optional)
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.1.114:5001/analyze_frame'));
      request.files.add(http.MultipartFile.fromBytes('frame', jpeg,
          filename: 'frame.jpg'));
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      // Example: backend returns landmarks as normalized x,y [0,1]
      final decoded = jsonDecode(responseData);
      List<dynamic> points = decoded['landmarks'] ?? [];

      setState(() {
        _landmarks = points
            .map<Offset>((p) => Offset(p[0] * _controller!.value.previewSize!.height,
                p[1] * _controller!.value.previewSize!.width))
            .toList();
      });
    } catch (e) {
      print("Error processing frame: $e");
    } finally {
      _isDetecting = false;
    }
  }

  // Converts CameraImage YUV420 -> JPEG
  Future<Uint8List> convertYUV420toJpeg(CameraImage image) async {
    final width = image.width;
    final height = image.height;

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final img = Uint8List(width * height * 3);

    int index = 0;
    for (int y = 0; y < height; y++) {
      final uvRow = (y ~/ 2) * uvRowStride;
      for (int x = 0; x < width; x++) {
        final yp = image.planes[0].bytes[y * image.planes[0].bytesPerRow + x];
        final up = image.planes[1].bytes[uvRow + (x ~/ 2) * uvPixelStride];
        final vp = image.planes[2].bytes[uvRow + (x ~/ 2) * uvPixelStride];

        int r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
        int g =
            (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round().clamp(0, 255);
        int b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

        img[index++] = r;
        img[index++] = g;
        img[index++] = b;
      }
    }
    // Encode RGB bytes to JPEG (use external library if needed)
    return img; // You can send raw RGB to Python backend
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Body Tracking")),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          CustomPaint(
            painter: PosePainter(_landmarks),
            child: Container(),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// 🎯 Painter to draw detected landmarks and body connections
class PosePainter extends CustomPainter {
  final List<Offset> points;
  final List<List<int>> connections;

  PosePainter(this.points, this.connections);

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.0;

    // Draw connections (limbs)
    for (var conn in connections) {
      if (conn.length < 2) continue;
      int start = conn[0];
      int end = conn[1];
      if (start >= 0 && end >= 0 && start < points.length && end < points.length) {
        canvas.drawLine(points[start], points[end], linePaint);
      }
    }

    // Draw joint points
    for (var point in points) {
      canvas.drawCircle(point, 4.0, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 🎥 Main page widget
class BodyTrackingPage extends StatefulWidget {
  const BodyTrackingPage({super.key});

  @override
  State<BodyTrackingPage> createState() => _BodyTrackingPageState();
}

class _BodyTrackingPageState extends State<BodyTrackingPage> {
  CameraController? _controller;
  bool _isRecording = false;
  String _statusMessage = "Press 'Record Form' to begin.";
  List<Offset> _landmarks = [];
  List<List<int>> _connections = [];
  late List<CameraDescription> cameras;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();

    // Use front camera if available
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    setState(() {});
  }

  // 📸 Capture one frame and send to backend
  Future<void> captureAndSendFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isRecording = true;
      _statusMessage = "Analyzing pose...";
    });

    try {
      // Capture frame
      final XFile file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();

      // Send frame to backend
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.114:5001/analyze_frame'), // 🔧 replace with your backend IP
  
        
      );

      request.files.add(http.MultipartFile.fromBytes(
        'frame',
        bytes,
        filename: 'frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      final decoded = jsonDecode(responseData);

      // Handle backend response
      if (decoded['pose_detected'] == false) {
        setState(() {
          _landmarks = [];
          _connections = [];
          _statusMessage = "Could not detect a person.";
        });
        return;
      }

      List<dynamic> points = decoded['landmarks'];
      List<dynamic> connData = decoded['connections'];

      // Scale landmarks to preview size
      final previewSize = _controller!.value.previewSize!;
      setState(() {
        _landmarks = points
            .map<Offset>((p) => Offset(
                  p['x'] * previewSize.width,
                  p['y'] * previewSize.height,
                ))
            .toList();

        _connections = connData.map<List<int>>((c) => [c[0], c[1]]).toList();
        _statusMessage = "Pose detected!";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error analyzing frame.";
      });
      print("Error: $e");
    } finally {
      setState(() => _isRecording = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Body Tracking")),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          CustomPaint(painter: PosePainter(_landmarks, _connections)),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
                label: Text(_isRecording ? "Analyzing..." : "Record Form"),
                onPressed: _isRecording ? null : captureAndSendFrame,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

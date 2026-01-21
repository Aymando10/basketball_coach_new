import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class PosePainter extends CustomPainter {
  final List<Offset> points;
  final List<List<int>> connections;

  PosePainter(this.points, this.connections);

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()..color = Colors.greenAccent;
    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2;

    Offset map(Offset p) => Offset(p.dx * size.width, p.dy * size.height);

    for (final c in connections) {
      if (c[0] < points.length && c[1] < points.length) {
        canvas.drawLine(map(points[c[0]]), map(points[c[1]]), linePaint);
      }
    }

    for (final p in points) {
      canvas.drawCircle(map(p), 5, jointPaint);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class BodyTrackingPage extends StatefulWidget {
  const BodyTrackingPage({super.key});

  @override
  State<BodyTrackingPage> createState() => _BodyTrackingPageState();
}

class _BodyTrackingPageState extends State<BodyTrackingPage> {
  CameraController? _controller;
  bool _busy = false;
  String _status = "Tap camera to analyze";
  int _score = 0;

  List<Offset> _points = [];
  List<List<int>> _connections = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    _controller = CameraController(
      cams.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _analyze() async {
    if (_busy || _controller == null) return;

    setState(() {
      _busy = true;
      _status = "Analyzing...";
    });

    final img = await _controller!.takePicture();
    final bytes = await img.readAsBytes();

    final uri = Uri.parse("http://192.168.1.114:5001/analyze_frame");

    final req = http.MultipartRequest("POST", uri)
      ..files.add(http.MultipartFile.fromBytes(
        "frame",
        bytes,
        filename: "frame.jpg",
        contentType: MediaType("image", "jpeg"),
      ));

    final res = await req.send();
    final body = await res.stream.bytesToString();
    final decoded = jsonDecode(body);

    if (decoded["pose_detected"] == true) {
      setState(() {
        _points = (decoded["landmarks"] as List)
            .map((p) => Offset(p["x"].toDouble(), p["y"].toDouble()))
            .toList();
        _connections = (decoded["connections"] as List)
            .map<List<int>>((c) => [c[0], c[1]])
            .toList();
        _score = decoded["score"];
        _status = "Score: $_score";
      });
    } else {
      setState(() {
        _points.clear();
        _connections.clear();
        _status = "No pose detected";
      });
    }

    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Shot Analysis")),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          CustomPaint(painter: PosePainter(_points, _connections)),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(_status, style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 12),
                FloatingActionButton(
                  onPressed: _analyze,
                  child: const Icon(Icons.camera),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

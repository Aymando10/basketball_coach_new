// pages/score_page.dart

import 'package:flutter/material.dart';

class ScorePage extends StatelessWidget {
  final int totalScore;
  final int elbowScore;
  final int kneeScore;
  final int wristScore;
  final int speedScore;
  final double elbow;
  final double knee;

  const ScorePage({
    super.key,
    required this.totalScore,
    required this.elbowScore,
    required this.kneeScore,
    required this.wristScore,
    required this.speedScore,
    required this.elbow,
    required this.knee,
  });

  Widget _buildBar(String label, int score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label ($score/25)"),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: score / 25,
          minHeight: 8,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shot Analysis")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              "$totalScore / 100",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 30),

            _buildBar("Knee Mechanics", kneeScore),
            _buildBar("Elbow Alignment", elbowScore),
            _buildBar("Wrist Follow-through", wristScore),
            _buildBar("Release Speed", speedScore),

            const SizedBox(height: 20),
            Text("Elbow at Release: ${elbow.toStringAsFixed(1)}°"),
            Text("Knee at Release: ${knee.toStringAsFixed(1)}°"),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back"),
            ),
          ],
        ),
      ),
    );
  }
}
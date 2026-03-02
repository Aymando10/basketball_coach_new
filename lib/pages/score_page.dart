// pages/score_page.dart

import 'package:flutter/material.dart';

class ScorePage extends StatelessWidget {
  final int score;
  final double elbow;
  final double knee;

  const ScorePage({
    super.key,
    required this.score,
    required this.elbow,
    required this.knee,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shot Analysis")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Score",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              "$score / 100",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 30),
            Text("Elbow Angle at Release: ${elbow.toStringAsFixed(1)}°"),
            Text("Knee Angle at Release: ${knee.toStringAsFixed(1)}°"),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back"),
            )
          ],
        ),
      ),
    );
  }
}
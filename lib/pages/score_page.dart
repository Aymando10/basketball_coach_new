// pages/score_page.dart
import 'package:flutter/material.dart';
import '../services/feedback_service.dart';

class ScorePage extends StatefulWidget {
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

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  final FeedbackService _feedback = FeedbackService();
  bool _showFeedback = false;

  Widget _buildBar(String label, int score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label ($score/25)"),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (score.clamp(0, 25)) / 25,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFeedbackCard({
    required String title,
    required int score,
    required FeedbackBand band,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  child: Text(
                    "$score/25",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              band.headline,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(band.detail),
            if (band.tips.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                "Tips",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...band.tips.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• "),
                      Expanded(child: Text(t)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<Widget> _buildFeedbackSection() async {
    final kneeTitle = await _feedback.getTitle('knee');
    final elbowTitle = await _feedback.getTitle('elbow');
    final wristTitle = await _feedback.getTitle('wrist');
    final speedTitle = await _feedback.getTitle('speed');

    final kneeBand = await _feedback.getBand('knee', widget.kneeScore);
    final elbowBand = await _feedback.getBand('elbow', widget.elbowScore);
    final wristBand = await _feedback.getBand('wrist', widget.wristScore);
    final speedBand = await _feedback.getBand('speed', widget.speedScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFeedbackCard(title: kneeTitle, score: widget.kneeScore, band: kneeBand),
        _buildFeedbackCard(title: elbowTitle, score: widget.elbowScore, band: elbowBand),
        _buildFeedbackCard(title: wristTitle, score: widget.wristScore, band: wristBand),
        _buildFeedbackCard(title: speedTitle, score: widget.speedScore, band: speedBand),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalScore.clamp(0, 100);

    return Scaffold(
      appBar: AppBar(title: const Text("Shot Analysis")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              "$total / 100",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildBar("Knee Mechanics", widget.kneeScore),
          _buildBar("Elbow Alignment", widget.elbowScore),
          _buildBar("Wrist Follow-through", widget.wristScore),
          _buildBar("Release Speed", widget.speedScore),

          const SizedBox(height: 6),
          Text("Elbow at Release: ${widget.elbow.toStringAsFixed(1)}°"),
          Text("Knee at Release: ${widget.knee.toStringAsFixed(1)}°"),

          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => setState(() => _showFeedback = !_showFeedback),
            child: Text(_showFeedback ? "Hide detailed feedback" : "Show detailed feedback"),
          ),

          const SizedBox(height: 12),
          if (_showFeedback)
            FutureBuilder<Widget>(
              future: _buildFeedbackSection(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text("Failed to load feedback: ${snapshot.error}"),
                  );
                }
                return snapshot.data ?? const SizedBox.shrink();
              },
            ),

          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back"),
          ),
        ],
      ),
    );
  }
}
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class Trophy {
  final String title;
  final String description;
  final bool unlocked;

  const Trophy(this.title, this.description, this.unlocked);
}

List<Trophy> evaluateTrophies(List<ShotRecord> shots) {
  return [
    Trophy("First Shot", "Take your first shot", shots.isNotEmpty),
    Trophy("Getting Started (10 shots)", "Hit 10 shots", shots.length >= 10),
    Trophy("Dedicated Shooter (50 shots)", "Hit 50 shots", shots.length >= 50),
    Trophy("Sharpshooter (90+)", "Score 90 or more points", shots.any((s) => s.totalScore >= 90)),
    Trophy("Perfect Shot (100)", "Score a perfect 100", shots.any((s) => s.totalScore == 100)),
    Trophy("Grinder (Consistent 80+)", "Average 80+ over 20 shots", shots.length >= 20 && shots.map((s) => s.totalScore).reduce((a, b) => a + b) / shots.length >= 80),
  ];
}

class TrophyCard extends StatelessWidget {
  final Trophy trophy;

  const TrophyCard({super.key, required this.trophy});

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(trophy.title),
        content: Text(trophy.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = trophy.unlocked;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showInfo(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: unlocked
              ? Colors.orange.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.12),
          border: Border.all(
            color: unlocked ? Colors.orange : Colors.grey,
          ),
        ),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.emoji_events : Icons.lock,
              color: unlocked ? Colors.orange : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                trophy.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: unlocked ? null : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseService _db = DatabaseService();
  List<ShotRecord> _shots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShots();
  }

  Future<void> _loadShots() async {
    final shots = await _db.getShots();
    if (!mounted) return;
    setState(() {
      _shots = shots;
      _loading = false;
    });
  }

  // ----------------------
  // Analytics helpers
  // ----------------------
  double _avgInt(Iterable<int> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double _stdDevInt(Iterable<int> xs) {
    final list = xs.toList();
    if (list.length < 2) return 0;
    final mean = _avgInt(list);
    final variance =
        list.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / list.length;
    return sqrt(variance);
  }

  int _bestInt(Iterable<int> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.reduce(max);
  }

  int _worstInt(Iterable<int> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.reduce(min);
  }

  String _weakestMechanic({
    required double elbowAvg,
    required double kneeAvg,
    required double wristAvg,
    required double speedAvg,
  }) {
    final entries = <String, double>{
      "Knee Mechanics": kneeAvg,
      "Elbow Alignment": elbowAvg,
      "Wrist Follow-through": wristAvg,
      "Release Speed": speedAvg,
    };

    final minEntry =
        entries.entries.reduce((a, b) => a.value <= b.value ? a : b);
    return minEntry.key;
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _mechanicRow(String label, double avgOutOf25) {
    final clamped = avgOutOf25.clamp(0, 25);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label (${clamped.toStringAsFixed(1)}/25)"),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: clamped / 25.0,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }

  void _showShotDetails(ShotRecord shot) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Shot #${shot.id ?? ''}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total: ${shot.totalScore}/100"),
            const SizedBox(height: 10),
            Text("Elbow score: ${shot.elbowScore}/25"),
            Text("Knee score: ${shot.kneeScore}/25"),
            Text("Wrist score: ${shot.wristScore}/25"),
            Text("Speed score: ${shot.speedScore}/25"),
            const SizedBox(height: 10),
            Text("Elbow angle: ${shot.elbowAngle.toStringAsFixed(1)}°"),
            Text("Knee angle: ${shot.kneeAngle.toStringAsFixed(1)}°"),
            const SizedBox(height: 10),
            Text("Time: ${shot.timestamp}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ----------------------
  // Chart helpers
  // ----------------------
  List<FlSpot> _buildScoreSpots(List<ShotRecord> shots, {int maxPoints = 30}) {
    // shots are ordered DESC (newest first). For a left->right timeline,
    // reverse so oldest is first.
    final ordered = shots.reversed.toList();
    final trimmed = ordered.length > maxPoints
        ? ordered.sublist(ordered.length - maxPoints)
        : ordered;

    return List.generate(trimmed.length, (i) {
      final s = trimmed[i].totalScore.toDouble();
      return FlSpot(i.toDouble(), s);
    });
  }

  double _movingAverageAt(List<double> values, int i, int window) {
    final start = max(0, i - window + 1);
    final slice = values.sublist(start, i + 1);
    return slice.reduce((a, b) => a + b) / slice.length;
  }

  List<FlSpot> _buildMovingAverageSpots(List<ShotRecord> shots,
      {int maxPoints = 30, int window = 5}) {
    final ordered = shots.reversed.toList();
    final trimmed = ordered.length > maxPoints
        ? ordered.sublist(ordered.length - maxPoints)
        : ordered;

    final ys = trimmed.map((s) => s.totalScore.toDouble()).toList();
    return List.generate(ys.length, (i) {
      final ma = _movingAverageAt(ys, i, window);
      return FlSpot(i.toDouble(), ma);
    });
  }

  Widget _scoreTrendChart() {
    if (_shots.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text("Log a few shots to see your score trend."),
      );
    }

    final spots = _buildScoreSpots(_shots, maxPoints: 30);
    final maSpots = _buildMovingAverageSpots(_shots, maxPoints: 30, window: 5);

    // y-axis bounds (pad a bit)
    final ys = spots.map((e) => e.y).toList();
    final minY = max(0.0, (ys.reduce(min) - 5).floorToDouble());
    final maxY = min(100.0, (ys.reduce(max) + 5).ceilToDouble());

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: true),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  // Keep it clean
                  return Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  // x is just index. We label sparsely.
                  return Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            // Raw scores
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              dotData: FlDotData(show: false),
            ),
            // Moving average
            LineChartBarData(
              spots: maSpots,
              isCurved: true,
              barWidth: 2,
              dotData: FlDotData(show: false),
              dashArray: [6, 6],
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((ts) {
                  final isMA = ts.barIndex == 1;
                  final label = isMA ? "5-Shot Average" : "Score";
                  return LineTooltipItem(
                    "$label: ${ts.y.toStringAsFixed(1)}",
                    Theme.of(context).textTheme.labelMedium!,
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scores = _shots.map((s) => s.totalScore);

    final avgScore = _avgInt(scores);
    final bestScore = _bestInt(scores);
    final worstScore = _worstInt(scores);
    final consistency = _stdDevInt(scores);

    final elbowAvg = _avgInt(_shots.map((s) => s.elbowScore));
    final kneeAvg = _avgInt(_shots.map((s) => s.kneeScore));
    final wristAvg = _avgInt(_shots.map((s) => s.wristScore));
    final speedAvg = _avgInt(_shots.map((s) => s.speedScore));

    final weakest = _shots.isEmpty
        ? "-"
        : _weakestMechanic(
            elbowAvg: elbowAvg,
            kneeAvg: kneeAvg,
            wristAvg: wristAvg,
            speedAvg: speedAvg,
          );

    // Recent form: last 10 avg vs previous 10 avg
    final last10 = _shots.take(10).toList();
    final prev10 = _shots.skip(10).take(10).toList();
    final last10Avg =
        last10.isEmpty ? 0 : _avgInt(last10.map((s) => s.totalScore));
    final prev10Avg =
        prev10.isEmpty ? 0 : _avgInt(prev10.map((s) => s.totalScore));
    final delta = (prev10.isEmpty) ? null : (last10Avg - prev10Avg);

    final trophies = evaluateTrophies(_shots);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadShots();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shots.isEmpty
              ? const Center(child: Text("No shots logged yet."))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      "Performance Overview",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      "Trophies",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),

                    const SizedBox(height: 12),
                    GridView.builder(
                      itemCount: trophies.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 3.5,
                      ),
                      itemBuilder: (context, index) {
                        return TrophyCard(trophy: trophies[index]);
                      },
                    ),

                    const SizedBox(height: 22),

                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        _statTile("Shots", "${_shots.length}"),
                        _statTile("Average", avgScore.toStringAsFixed(1)),
                        _statTile("Best", "$bestScore"),
                        _statTile("Consistency", "±${consistency.toStringAsFixed(1)}"),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Score trend chart
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Score Trend (last 30)",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 10),
                          _scoreTrendChart(),
                          const SizedBox(height: 6),
                          Text(
                            "Dashed line is a 5-shot moving average.",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Recent form card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Recent Form",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text("Last 10 avg: ${last10Avg.toStringAsFixed(1)}"),
                          if (prev10.isNotEmpty)
                            Text("Previous 10 avg: ${prev10Avg.toStringAsFixed(1)}"),
                          const SizedBox(height: 6),
                          Text(
                            prev10.isEmpty
                                ? "Log 20+ shots to compare trends."
                                : (delta! >= 0
                                    ? "Improving: +${delta.toStringAsFixed(1)}"
                                    : "Dropping: ${delta.toStringAsFixed(1)}"),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: prev10.isEmpty
                                  ? Theme.of(context).textTheme.bodyMedium?.color
                                  : (delta! >= 0 ? Colors.green : Colors.red),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text("Worst shot: $worstScore"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      "Mechanics Breakdown",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mechanicRow("Knee Mechanics", kneeAvg),
                          _mechanicRow("Elbow Alignment", elbowAvg),
                          _mechanicRow("Wrist Follow-through", wristAvg),
                          _mechanicRow("Release Speed", speedAvg),
                          const SizedBox(height: 4),
                          Text(
                            "Weakest mechanic: $weakest",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      "Shot History",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),

                    ..._shots.map((shot) {
                      final date = shot.timestamp.length >= 10
                          ? shot.timestamp.substring(0, 10)
                          : shot.timestamp;

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text("Score: ${shot.totalScore}/100"),
                            subtitle: Text(
                              "Elbow ${shot.elbowScore}/25 • Knee ${shot.kneeScore}/25 • Wrist ${shot.wristScore}/25 • Speed ${shot.speedScore}/25",
                            ),
                            trailing: Text(date),
                            onTap: () => _showShotDetails(shot),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
                ),
    );
  }
}
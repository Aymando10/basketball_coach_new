import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'body_tracking_page.dart';
import 'profile_page.dart';
import 'learn_shot_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _db = DatabaseService();

  List<ShotRecord> _shots = [];

  int _averageScore = 0;
  int _bestScore = 0;
  int _worstScore = 0;

  @override
  void initState() {
    super.initState();
    _loadShots();
  }

  Future<void> _loadShots() async {
    final shots = await _db.getShots();

    if (shots.isEmpty) {
      setState(() => _shots = []);
      return;
    }

    int total = 0;
    int best = 0;
    int worst = 100;

    for (final s in shots) {
      total += s.totalScore;

      if (s.totalScore > best) best = s.totalScore;
      if (s.totalScore < worst) worst = s.totalScore;
    }

    setState(() {
      _shots = shots;
      _averageScore = (total / shots.length).round();
      _bestScore = best;
      _worstScore = worst;
    });
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _navCard(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Colors.deepOrange),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentShots() {
    final recent = _shots.take(3).toList();

    if (recent.isEmpty) {
      return const Text("No shots recorded yet.");
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: recent
          .map(
            (shot) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${shot.totalScore}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            // Start Analysis Button
            ElevatedButton.icon(
              icon: const Icon(Icons.sports_basketball),
              label: const Text(
                "Start Shot Analysis",
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BodyTrackingPage(),
                  ),
                ).then((_) => _loadShots());
              },
            ),

            const SizedBox(height: 30),

            const Text(
              "Last Session",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _statCard("Average", "$_averageScore"),
                const SizedBox(width: 10),
                _statCard("Best", "$_bestScore"),
                const SizedBox(width: 10),
                _statCard("Worst", "$_worstScore"),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              "Recent Shots",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _recentShots(),

            const SizedBox(height: 30),

            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _navCard(
                  "Shot History",
                  Icons.history,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfilePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _navCard(
                  "Learn Shot Form",
                  Icons.menu_book,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LearningLiteraturePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
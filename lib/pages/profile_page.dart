import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final int level = 3;
  final int xp = 120;
  final int xpToNext = 200;

  final List<String> achievementsUnlocked = [
    "First Session Completed",
    "10 Shots Analysed",
  ];

  final List<String> achievementsLocked = [
    "50 Shots Analysed",
    "100 Shots Analysed",
    "Completed 10 Shooting Drills",
    "Achieved 80% Accuracy in Dribbling Tests",
    "Finished Advanced Passing Course",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Player Header
            const Text(
              "Player Profile",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            /// Level & XP
            Text("Level $level",
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: xp / xpToNext,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 8),
            Text("$xp / $xpToNext XP"),

            const SizedBox(height: 30),

            /// Achievements
            const Text(
              "Achievements",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ...achievementsUnlocked.map((a) => ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(a),
                )),

            ...achievementsLocked.map((a) => ListTile(
                  leading: const Icon(Icons.lock, color: Colors.grey),
                  title: Text(a),
                )),

            const SizedBox(height: 30),

            /// Stats (placeholders)
            const Text(
              "Stats",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Sessions Completed: 5"),
            const Text("Shots Analysed: 47"),
            const Text("Days Active: 3"),
          ],
        ),
      ),
    );
  }
}
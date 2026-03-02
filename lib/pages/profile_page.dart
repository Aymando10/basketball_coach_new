// pages/profile_page.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseService _db = DatabaseService();
  List<ShotRecord> _shots = [];

  @override
  void initState() {
    super.initState();
    _loadShots();
  }

  Future<void> _loadShots() async {
    final shots = await _db.getShots();
    setState(() => _shots = shots);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: ListView.builder(
        itemCount: _shots.length,
        itemBuilder: (_, index) {
          final shot = _shots[index];

          return ListTile(
            title: Text("Score: ${shot.score}/100"),
            subtitle: Text(
                "Elbow: ${shot.elbowAngle.toStringAsFixed(1)}°, Knee: ${shot.kneeAngle.toStringAsFixed(1)}°"),
            trailing: Text(
              shot.timestamp.substring(0, 10),
            ),
          );
        },
      ),
    );
  }
}
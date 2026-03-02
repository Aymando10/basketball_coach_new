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

  @override
  Widget build(BuildContext context) {
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
              : ListView.separated(
                  itemCount: _shots.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final shot = _shots[index];

                    final date = shot.timestamp.length >= 10
                        ? shot.timestamp.substring(0, 10)
                        : shot.timestamp;

                    return ListTile(
                      title: Text("Score: ${shot.totalScore}/100"),
                      subtitle: Text(
                        "Elbow ${shot.elbowScore}/25 • Knee ${shot.kneeScore}/25 • Wrist ${shot.wristScore}/25 • Speed ${shot.speedScore}/25",
                      ),
                      trailing: Text(date),
                      onTap: () => _showShotDetails(shot),
                    );
                  },
                ),
    );
  }
}
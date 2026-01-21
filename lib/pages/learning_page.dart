import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Simple data model (unchanged)
class CoachingVideo {
  final String title;
  final String youtubeId;

  const CoachingVideo({
    required this.title,
    required this.youtubeId,
  });
}

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  /// Video categories (same content as your original)
  late final Map<String, List<CoachingVideo>> _videoCategories;

  /// One controller per video (CRITICAL)
  final Map<String, YoutubePlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();

    _videoCategories = {
      "Shooting Techniques": const [
        CoachingVideo(
          title: "Shoot with Great Form, with Klay Thompson",
          youtubeId: "8-7JVqPlUJ4",
        ),
      ],
      "Dribbling Drills": const [],
      "Passing": const [],
      "Athletic Conditioning": const [],
    };

    /// Create controllers ONCE
    for (final category in _videoCategories.values) {
      for (final video in category) {
        _controllers[video.youtubeId] =
            YoutubePlayerController.fromVideoId(
          videoId: video.youtubeId,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    /// Dispose ALL controllers (MANDATORY)
    for (final controller in _controllers.values) {
      controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Learning Videos")),
      body: ListView(
        children: _videoCategories.entries.map((category) {
          return ExpansionTile(
            title: Text(
              category.key,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: category.value.map((video) {
              final controller = _controllers[video.youtubeId]!;

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: YoutubePlayer(
                        controller: controller,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

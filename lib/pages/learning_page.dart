import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple data model
class CoachingVideo {
  final String title;
  final String youtubeId;

  const CoachingVideo({
    required this.title,
    required this.youtubeId,
  });

  /// High-quality thumbnail URL from YouTube 
  String get thumbnailUrl => "https://img.youtube.com/vi/$youtubeId/hqdefault.jpg";

  /// Standard watch URL
  Uri get watchUrl => Uri.parse("https://www.youtube.com/watch?v=$youtubeId");
}

/// Learning page with categories + video cards.
/// Tapping a video opens YouTube app (if available) or Safari.
class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  late final Map<String, List<CoachingVideo>> _videoCategories;

  @override
  void initState() {
    super.initState();

    
_videoCategories = {
      "Shooting Techniques": const [
        CoachingVideo(
          title: "Shoot with Great Form, with Klay Thompson",
          youtubeId: "8-7JVqPlUJ4",
        ),
        CoachingVideo(title: "A lesson with Kobe", 
        youtubeId: "aSqeWUuQSlM"
        ),
      ],
      "Dribbling Drills": const [
        CoachingVideo(
          title: "Improve Your Ball Handling with Phil Handy",
          youtubeId: "Dk65Bq24OyQ",
        ),
      ],
      "Passing": const [],
      "Athletic Conditioning": const [
        CoachingVideo(
          title: "1 Hour Uncut Workout with LeBron James",
          youtubeId: "wQWmRIHavC8",
        ),
        CoachingVideo(title: "Steph Curry's Off-Season Workout", 
        youtubeId: "6mnujT_fzlY",
        ),
      ],
    };
  }

  Future<void> _openVideo(CoachingVideo video) async {
    // This opens externally (YouTube app if installed, otherwise Safari).
    // This avoids all embed restrictions.
    final url = video.watchUrl;

    final ok = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open YouTube.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Learning Videos")),
      body: ListView(
        children: _videoCategories.entries.map((category) {
          final videos = category.value;

          return ExpansionTile(
            title: Text(
              category.key,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            children: videos.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("No videos added yet."),
                    )
                  ]
                : videos.map((video) {
                    return _VideoCard(
                      video: video,
                      onTap: () => _openVideo(video),
                    );
                  }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

/// A simple card showing thumbnail + title.
/// Keeps UI fast and avoids WebViews in scroll lists (which can freeze iOS).
class _VideoCard extends StatelessWidget {
  final CoachingVideo video;
  final VoidCallback onTap;

  const _VideoCard({
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    // Simple loading placeholder
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    // Fallback if thumbnail fails (rare)
                    errorBuilder: (context, error, stack) {
                      return const Center(child: Icon(Icons.broken_image, size: 36));
                    },
                  ),
                ),
              ),

              // Title row
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        video.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

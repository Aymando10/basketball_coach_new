// pages/learning_literature_page.dart
import 'package:flutter/material.dart';

class LearningLiteraturePage extends StatelessWidget {
  const LearningLiteraturePage({super.key});

  static final Map<String, List<LiteratureCardItem>> _literatureCategories = {
    "Why shooting matters": [
      LiteratureCardItem(
        title: "Spacing & offensive rating: why teams need shooters",
        bullets: const [
          "Modern lineups often require 3–4 reliable shooters to create spacing and improve offensive rating.",
          "This reflects the shift away from early-2000s close-to-rim heavy playstyles.",
        ],
        references: const ["Tan (2025)"],
      ),
      LiteratureCardItem(
        title: "Three-point volume & win probability",
        bullets: const [
          "Increasing three-point attempts and the percentage of three-point offense can raise the probability of winning.",
          "Teams with higher 3PA rates and 3P% tend to outperform teams relying more on interior scoring.",
        ],
        references: const ["Gou & Zhang (2022)"],
      ),
      LiteratureCardItem(
        title: "Analytics & expected value: why shot selection changed",
        bullets: const [
          "Sports analytics contributed to the shift toward three-point emphasis.",
          "A 35% 3PT shot yields ~1.05 points/shot vs a 45% mid-range shot yielding ~0.9 points/shot.",
        ],
        references: const ["Kilcoyne, Nguyen & Mcdonnell (2020)"],
      ),
    ],

    "Biomechanics: what makes a good shot": [
      LiteratureCardItem(
        title: "Arm segments & joint roles at release",
        bullets: const [
          "Shoulder rotation contributes strongly to the vertical component of release velocity (shot arc).",
          "Elbow extension contributes to both horizontal + vertical components and helps transfer lower-limb energy to the upper body.",
          "Wrist flexion influences backspin, improving the chance of a make.",
          "There are many joint-angle/velocity combinations that can produce similar release conditions (no single perfect form).",
        ],
        references: const ["Okubo & Hubbard (2015)"],
      ),
      LiteratureCardItem(
        title: "Proficient free-throw shooters: control & posture",
        bullets: const [
          "More proficient shooters show lower peak/mean angular velocities at the knee and center of mass (more controlled movement).",
          "They also tend to have greater release height and less forward trunk lean at release.",
          "Overemphasizing release height may be counterproductive.",
        ],
        references: const ["Cabarkapa et al. (2023)"],
      ),
    ],

    "Numeric targets used for scoring": [
      LiteratureCardItem(
        title: "Knee flexion range for successful jump shots (pre-jump)",
        bullets: const [
          "Highest jump-shot success was associated with knee angle ~71.3°–100.9° before jumping.",
          "Excessive knee flexion can increase stress on the extensor group and negatively affect accuracy.",
        ],
        references: const ["Mukhtarsyaf et al. (2024)"],
      ),
      LiteratureCardItem(
        title: "Release angle guidance",
        bullets: const [
          "A release angle in the ~50°–55° range can increase the chance of the ball dropping in due to a higher entry angle / effective rim area.",
        ],
        references: const ["Bartlett (2014)"],
      ),
      LiteratureCardItem(
        title: "Example values: release angle & velocity",
        bullets: const [
          "One example (for a 1.92m player) reports ~45° release angle and ~8.75 m/s release velocity for a successful three-point shot.",
          "Treat these as contextual reference values rather than universal targets.",
        ],
        references: const ["Kizilhan (2023)"],
      ),
    ],

    "Computer vision & pose estimation": [
      LiteratureCardItem(
        title: "Pose-estimation as a practical alternative to lab motion capture",
        bullets: const [
          "High-precision motion capture is accurate but expensive and not practical outside lab/pro settings.",
          "Pose-estimation frameworks enable joint landmark tracking using smartphone cameras.",
        ],
        references: const ["Cabarkapa et al. (2023)"],
      ),
      LiteratureCardItem(
        title: "CV for biomechanics: evidence of feasibility",
        bullets: const [
          "Computer vision + pose estimation can be used to derive biomechanical insights (e.g., jump-landing analysis).",
          "This supports the idea that joint-angle based feedback can be viable outside a lab environment.",
        ],
        references: const ["Sharma et al. (2024)"],
      ),
      LiteratureCardItem(
        title: "Transformer-based pose estimation: where the field is heading",
        bullets: const [
          "KASportsFormer uses anatomy/kinematic-informed features (Bone Extractor, Limb Fuser) to improve kinematic motion representation.",
          "Highlights the value of error-reduction techniques beyond raw landmark positions.",
        ],
        references: const ["Yin et al. (2025)"],
      ),
    ],

    "Limitations & how we should interpret feedback": [
      LiteratureCardItem(
        title: "No single universal 'perfect' form",
        bullets: const [
          "Multiple movement solutions can achieve similar release conditions (degeneracy).",
          "Literature describes tendencies/ranges of effective form, not one strict template for everyone.",
          "Shooting is influenced by many factors beyond mechanics (experience, confidence, etc.).",
        ],
        references: const ["Okubo & Hubbard (2015)", "Okazaki et al. (2015)"],
      ),
      LiteratureCardItem(
        title: "Lab vs real-world constraints",
        bullets: const [
          "Many studies are conducted in controlled conditions (lighting, distance, noise).",
          "Real games add constraints that aren’t fully captured in lab settings.",
        ],
        references: const ["(Your limitations discussion in Section 2.6)"],
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Learning (Research)")),
      body: ListView(
        children: _literatureCategories.entries.map((category) {
          final items = category.value;

          return ExpansionTile(
            title: Text(
              category.key,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            children: items.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("No notes added yet."),
                    )
                  ]
                : items.map((item) => _LiteratureCard(item: item)).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class LiteratureCardItem {
  final String title;
  final List<String> bullets;
  final List<String> references;

  const LiteratureCardItem({
    required this.title,
    required this.bullets,
    required this.references,
  });
}

class _LiteratureCard extends StatelessWidget {
  final LiteratureCardItem item;

  const _LiteratureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  const Icon(Icons.menu_book, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bullet points
              ...item.bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("•  "),
                      Expanded(
                        child: Text(
                          b,
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // References
              if (item.references.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "References: ${item.references.join("; ")}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            height: 1.25,
                          ),
                        ),
                      ),
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
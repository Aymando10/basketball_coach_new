import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class FeedbackBand {
  final int minScore;
  final int maxScore;
  final String headline;
  final String detail;
  final List<String> tips;

  FeedbackBand({
    required this.minScore,
    required this.maxScore,
    required this.headline,
    required this.detail,
    required this.tips,
  });

  factory FeedbackBand.fromJson(Map<String, dynamic> json) {
    return FeedbackBand(
      minScore: json['minScore'] as int,
      maxScore: json['maxScore'] as int,
      headline: json['headline'] as String,
      detail: json['detail'] as String,
      tips: (json['tips'] as List).map((e) => e.toString()).toList(),
    );
  }

  bool matches(int score) => score >= minScore && score <= maxScore;
}

class FeedbackCategory {
  final String title;
  final List<FeedbackBand> bands;

  FeedbackCategory({
    required this.title,
    required this.bands,
  });

  factory FeedbackCategory.fromJson(Map<String, dynamic> json) {
    return FeedbackCategory(
      title: json['title'] as String,
      bands: (json['bands'] as List)
          .map((e) => FeedbackBand.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  FeedbackBand bandFor(int score) {
    // First match wins; fallback to last band.
    for (final b in bands) {
      if (b.matches(score)) return b;
    }
    return bands.isNotEmpty
        ? bands.last
        : FeedbackBand(
            minScore: 0,
            maxScore: 25,
            headline: "No feedback available",
            detail: "No bands were defined for this category.",
            tips: const [],
          );
  }
}

class FeedbackService {
  Map<String, FeedbackCategory>? _cache;

  Future<void> _ensureLoaded() async {
    if (_cache != null) return;

    final raw = await rootBundle.loadString('assets/feedback_rules.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    _cache = decoded.map((key, value) {
      return MapEntry(
        key,
        FeedbackCategory.fromJson(value as Map<String, dynamic>),
      );
    });
  }

  Future<FeedbackBand> getBand(String key, int score) async {
    await _ensureLoaded();
    final category = _cache![key];
    if (category == null) {
      return FeedbackBand(
        minScore: 0,
        maxScore: 25,
        headline: "No feedback available",
        detail: "Feedback rules missing for '$key'.",
        tips: const [],
      );
    }
    return category.bandFor(score);
  }

  Future<String> getTitle(String key) async {
    await _ensureLoaded();
    return _cache![key]?.title ?? key;
  }
}
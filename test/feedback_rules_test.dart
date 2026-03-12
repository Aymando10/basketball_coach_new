import 'package:flutter_test/flutter_test.dart';
import 'package:basketball_coach/services/feedback_service.dart';

void main() {
  test('FeedbackCategory returns correct band for score', () {
    // Arrange
    final category = FeedbackCategory(
      title: "Knee Mechanics",
      bands: [
        FeedbackBand(
          minScore: 0,
          maxScore: 10,
          headline: "Needs work",
          detail: "Basic knee mechanics issues detected.",
          tips: const ["Try dipping deeper."],
        ),
        FeedbackBand(
          minScore: 11,
          maxScore: 20,
          headline: "Decent",
          detail: "You are close to the target range.",
          tips: const ["Keep your dip controlled."],
        ),
        FeedbackBand(
          minScore: 21,
          maxScore: 25,
          headline: "Excellent",
          detail: "Strong knee mechanics.",
          tips: const ["Maintain this consistency."],
        ),
      ],
    );

    // Act
    final bandLow = category.bandFor(7);
    final bandMid = category.bandFor(18);
    final bandHigh = category.bandFor(24);

    // Assert
    expect(bandLow.headline, "Needs work");
    expect(bandMid.headline, "Decent");
    expect(bandHigh.headline, "Excellent");
  });
}
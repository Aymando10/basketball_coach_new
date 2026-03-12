import 'package:flutter_test/flutter_test.dart';
import 'package:basketball_coach/pages/profile_page.dart';
import 'package:basketball_coach/services/database_service.dart';

void main() {
  test('Trophy evaluation unlocks expected trophies', () {
    // Arrange
    final shots = List.generate(20, (i) {
      return ShotRecord(
        id: i + 1,
        elbowAngle: 170,
        kneeAngle: 90,
        totalScore: (i == 0) ? 100 : 85, // includes a perfect shot
        elbowScore: 21,
        kneeScore: 21,
        wristScore: 21,
        speedScore: 22,
        releaseTimeMs: 1000 + i,
        timestamp: "2026-03-11T12:00:00.000Z",
      );
    });

    // Act
    final trophies = evaluateTrophies(shots);

    bool unlocked(String title) =>
        trophies.firstWhere((t) => t.title == title).unlocked;

    // Assert
    expect(unlocked("First Shot"), true);
    expect(unlocked("Getting Started (10 shots)"), true);
    expect(unlocked("Perfect Shot (100)"), true);
    expect(unlocked("Dedicated Shooter (50 shots)"), false);
  });
}
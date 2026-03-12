import 'package:flutter_test/flutter_test.dart';
import 'package:basketball_coach/services/database_service.dart';

void main() {
  test('ShotRecord map serialization round-trip', () {
    // Arrange
    final original = ShotRecord(
      id: 7,
      elbowAngle: 172.5,
      kneeAngle: 88.2,
      totalScore: 91,
      elbowScore: 23,
      kneeScore: 22,
      wristScore: 24,
      speedScore: 22,
      releaseTimeMs: 123456,
      timestamp: "2026-03-11T12:34:56.000Z",
    );

    // Act
    final map = original.toMap();
    final decoded = ShotRecord.fromMap(map);

    // Assert
    expect(decoded.id, original.id);
    expect(decoded.elbowAngle, original.elbowAngle);
    expect(decoded.kneeAngle, original.kneeAngle);
    expect(decoded.totalScore, original.totalScore);
    expect(decoded.elbowScore, original.elbowScore);
    expect(decoded.kneeScore, original.kneeScore);
    expect(decoded.wristScore, original.wristScore);
    expect(decoded.speedScore, original.speedScore);
    expect(decoded.releaseTimeMs, original.releaseTimeMs);
    expect(decoded.timestamp, original.timestamp);
  });
}
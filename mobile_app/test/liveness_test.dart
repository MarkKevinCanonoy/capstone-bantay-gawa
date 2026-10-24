import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/liveness_detector.dart';

void main() {
  group('CNN Anti-Spoofing Liveness Tests', () {
    test('Generates random valid liveness motion challenge', () {
      final challenge = LivenessDetector.getRandomChallenge();
      expect(challenge, isNotNull);
      expect(challenge.instructionsFilipino, isNotEmpty);
      expect(challenge.instructionsEnglish, isNotEmpty);
    });

    test('Verifies live dynamic motion frames return isLive true with high confidence', () async {
      final result = await LivenessDetector.verifyLiveness(
        challenge: LivenessChallenge.blink,
        frameDeltas: [
          [0.18, 0.22, 0.19],
          [0.21, 0.25, 0.20],
        ],
      );

      expect(result.isLive, isTrue);
      expect(result.confidenceScore, greaterThanOrEqualTo(0.90));
    });
  });
}

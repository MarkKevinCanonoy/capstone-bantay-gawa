import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/biometrics_helper.dart';

void main() {
  group('BiometricsHelper Tests', () {
    test('Identical vectors produce cosine similarity of 1.0', () {
      final vecA = [0.1, 0.2, 0.3, 0.4, 0.5];
      final similarity = BiometricsHelper.cosineSimilarity(vecA, vecA);
      expect(similarity, closeTo(1.0, 0.0001));
    });

    test('Orthogonal vectors produce cosine similarity of 0.0', () {
      final vecA = [1.0, 0.0];
      final vecB = [0.0, 1.0];
      final similarity = BiometricsHelper.cosineSimilarity(vecA, vecB);
      expect(similarity, closeTo(0.0, 0.0001));
    });

    test('Parses embedding string to list of doubles', () {
      const str = '0.123, 0.456, 0.789';
      final list = BiometricsHelper.parseEmbeddingString(str);
      expect(list.length, equals(3));
      expect(list[0], closeTo(0.123, 0.001));
      expect(list[1], closeTo(0.456, 0.001));
      expect(list[2], closeTo(0.789, 0.001));
    });
  });
}

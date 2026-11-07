import 'dart:typed_data';
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

    test('extractFeatureVector extracts 512-dimensional normalized unit vector', () {
      final fakeImageBytes = Uint8List.fromList(List.generate(1024, (i) => (i * 17) % 256));
      final vector = BiometricsHelper.extractFeatureVector(fakeImageBytes);

      expect(vector.length, equals(512));

      // Calculate L2 norm
      double normSq = 0.0;
      for (final v in vector) {
        normSq += v * v;
      }
      expect(normSq, closeTo(1.0, 0.001));
    });

    test('Threshold strictly distinguishes match from mismatch', () {
      expect(BiometricsHelper.matchThreshold, equals(0.65));

      // Identical image extracts produce identical vector with similarity 1.0
      final imageBytes = Uint8List.fromList(List.generate(512, (i) => (i * 31) % 256));
      final enrolledVector = BiometricsHelper.extractFeatureVector(imageBytes);
      final capturedVector = BiometricsHelper.extractFeatureVector(imageBytes);

      final matchSimilarity = BiometricsHelper.cosineSimilarity(capturedVector, enrolledVector);
      expect(matchSimilarity, greaterThanOrEqualTo(BiometricsHelper.matchThreshold));

      // Random different vector fails threshold
      final differentBytes = Uint8List.fromList(List.generate(512, (i) => 255 - (i * 31) % 256));
      final differentVector = BiometricsHelper.extractFeatureVector(differentBytes);
      final diffSimilarity = BiometricsHelper.cosineSimilarity(differentVector, enrolledVector);
      expect(diffSimilarity, lessThan(BiometricsHelper.matchThreshold));
    });

    test('Cosine similarity matches front-camera selfie mirror inversion', () {
      final imageBytes = Uint8List.fromList(List.generate(512, (i) => (i * 37) % 256));
      final baseVector = BiometricsHelper.extractFeatureVector(imageBytes);
      final mirroredVector = BiometricsHelper.mirrorVector(baseVector);

      final sim = BiometricsHelper.cosineSimilarity(mirroredVector, baseVector);
      expect(sim, greaterThanOrEqualTo(BiometricsHelper.matchThreshold));
    });

    test('Cosine similarity matches 90-degree and 270-degree rotated sensors', () {
      final imageBytes = Uint8List.fromList(List.generate(512, (i) => (i * 41) % 256));
      final baseVector = BiometricsHelper.extractFeatureVector(imageBytes);
      final rot90Vector = BiometricsHelper.rotateSpatialVector(baseVector, 90);
      final rot270Vector = BiometricsHelper.rotateSpatialVector(baseVector, 270);

      expect(BiometricsHelper.cosineSimilarity(rot90Vector, baseVector), greaterThanOrEqualTo(BiometricsHelper.matchThreshold));
      expect(BiometricsHelper.cosineSimilarity(rot270Vector, baseVector), greaterThanOrEqualTo(BiometricsHelper.matchThreshold));
    });
  });
}

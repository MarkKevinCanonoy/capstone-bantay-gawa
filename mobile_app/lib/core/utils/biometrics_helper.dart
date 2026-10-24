import 'dart:math' as math;

class BiometricsHelper {
  BiometricsHelper._();

  /// Default threshold for face verification matching (MobileFaceNet standard)
  static const double matchThreshold = 0.75;

  /// Calculates cosine similarity between two face embedding vectors.
  /// Result ranges from -1.0 to 1.0 (values >= 0.75 indicate a strong biometric match).
  static double cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.isEmpty || vectorB.isEmpty || vectorA.length != vectorB.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }

    if (normA <= 0.0 || normB <= 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Parses a comma-separated string from the database `users.face_embedding` column
  /// into a list of double values.
  static List<double> parseEmbeddingString(String embeddingStr) {
    try {
      final clean = embeddingStr.replaceAll('[', '').replaceAll(']', '').trim();
      if (clean.isEmpty) return [];
      return clean.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).toList();
    } catch (_) {
      return [];
    }
  }

  /// Serializes a list of doubles to a string for database storage.
  static String formatEmbeddingString(List<double> vector) {
    return vector.map((v) => v.toStringAsFixed(6)).join(',');
  }
}

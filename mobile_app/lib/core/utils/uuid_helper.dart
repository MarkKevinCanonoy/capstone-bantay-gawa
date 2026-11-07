import 'dart:math';

class UuidHelper {
  UuidHelper._();

  static final Random _random = Random.secure();

  /// Generates a standard RFC4122 Version 4 UUID string (e.g. "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d").
  static String generate() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10xx
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Validates whether [str] is a valid 36-character RFC4122 UUID format.
  static bool isValidUuid(String? str) {
    if (str == null || str.trim().isEmpty) return false;
    return _uuidRegex.hasMatch(str.trim());
  }
}

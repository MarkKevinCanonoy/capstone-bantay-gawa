import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_app/core/utils/image_watermark_helper.dart';

void main() {
  group('ImageWatermarkHelper Tests', () {
    test('Burns watermark onto raw image and produces valid encoded JPEG', () {
      // Create a small 100x100 dummy test image
      final sampleImg = img.Image(width: 150, height: 150);
      img.fill(sampleImg, color: img.ColorRgb8(200, 200, 200));
      final rawBytes = Uint8List.fromList(img.encodeJpg(sampleImg));

      final watermarkedBytes = ImageWatermarkHelper.burnWatermark(
        rawImageBytes: rawBytes,
        latitude: 11.0050,
        longitude: 124.6075,
        workerName: 'Juan Dela Cruz',
        workAreaName: 'Sector 4 - Downtown Zone',
        timestamp: DateTime(2026, 10, 25, 8, 30, 0),
      );

      expect(watermarkedBytes, isNotEmpty);
      final decoded = img.decodeJpg(watermarkedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(150));
      expect(decoded.height, equals(150));
    });
  });
}

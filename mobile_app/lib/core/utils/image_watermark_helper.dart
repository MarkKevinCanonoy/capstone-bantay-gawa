import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class ImageWatermarkHelper {
  ImageWatermarkHelper._();

  /// Burns timestamp, GPS coordinates, address, and worker metadata
  /// directly into the image bytes, strictly satisfying Rule 4 of GEMINI.md.
  static Uint8List burnWatermark({
    required Uint8List rawImageBytes,
    required double latitude,
    required double longitude,
    required String workerName,
    required String workAreaName,
    DateTime? timestamp,
  }) {
    final image = img.decodeImage(rawImageBytes);
    if (image == null) return rawImageBytes;

    final now = timestamp ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final gpsStr = 'GPS: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    final areaStr = 'ZONE: $workAreaName (Ormoc City, Leyte)';
    final workerStr = 'WORKER: $workerName';

    // Banner dimensions at bottom of image
    const int bannerHeight = 85;
    final int bannerTop = image.height - bannerHeight > 0 ? image.height - bannerHeight : 0;

    // Draw dark semi-transparent rectangle banner at bottom
    img.fillRect(
      image,
      x1: 0,
      y1: bannerTop,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(8, 40, 75, 220), // Navy banner
    );

    // Draw metadata strings onto the banner
    final font = img.arial14;
    final textColor = img.ColorRgba8(255, 255, 255, 255);
    final accentColor = img.ColorRgba8(108, 197, 255, 255);

    img.drawString(image, 'BANTAYGAWA • ENRO ORMOC CITY', font: font, x: 12, y: bannerTop + 8, color: accentColor);
    img.drawString(image, '$dateStr • $gpsStr', font: font, x: 12, y: bannerTop + 26, color: textColor);
    img.drawString(image, areaStr, font: font, x: 12, y: bannerTop + 44, color: textColor);
    img.drawString(image, workerStr, font: font, x: 12, y: bannerTop + 62, color: accentColor);

    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }
}

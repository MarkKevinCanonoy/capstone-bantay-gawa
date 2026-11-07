import 'package:flutter/foundation.dart';

void downloadFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  debugPrint('File download ($filename) stubbed for non-web environment (${content.length} bytes).');
}

void downloadBytes({
  required String filename,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) {
  debugPrint('Byte download ($filename) stubbed for non-web environment (${bytes.length} bytes).');
}

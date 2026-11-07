// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  // Prepend UTF-8 BOM character (\uFEFF) as a string part so Excel recognizes UTF-8 text directly
  final bomString = content.startsWith('\uFEFF') ? content : '\uFEFF$content';
  final blob = html.Blob([bomString], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void downloadBytes({
  required String filename,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) {
  // Uint8List is recognized by html.Blob as an ArrayBufferView, preserving binary bytes
  final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = html.Blob([uint8], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

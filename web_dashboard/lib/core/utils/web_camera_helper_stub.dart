import 'dart:typed_data';

class WebCameraDevice {
  final String deviceId;
  final String label;

  const WebCameraDevice({required this.deviceId, required this.label});
}

class WebCameraHelper {
  static Future<List<WebCameraDevice>> getVideoDevices() async => [];

  static Future<dynamic> startStream([String? deviceId]) async => null;

  static Uint8List? captureFrame(dynamic videoElement) => null;

  static void stopStream(dynamic stream, [dynamic videoElement]) {}

  static void registerVideoView(String viewType, dynamic videoElement) {}

  static dynamic createVideoElement() => null;

  static void attachStream(dynamic videoElement, dynamic stream) {}

  static Future<Uint8List?> pickImageFile({
    required Function(String errorMessage) onError,
  }) async => null;
}

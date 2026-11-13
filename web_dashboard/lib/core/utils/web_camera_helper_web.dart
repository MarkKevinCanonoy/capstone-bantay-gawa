// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebCameraDevice {
  final String deviceId;
  final String label;

  const WebCameraDevice({required this.deviceId, required this.label});
}

class WebCameraHelper {
  /// Enumerate video input devices (laptop webcam, USB webcams)
  static Future<List<WebCameraDevice>> getVideoDevices() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) return [];
      final devices = await mediaDevices.enumerateDevices();
      final videoInputs = <WebCameraDevice>[];
      int camIndex = 1;
      for (final device in devices) {
        if (device.kind == 'videoinput') {
          final id = device.deviceId ?? '';
          final label = (device.label != null && device.label!.trim().isNotEmpty)
              ? device.label!
              : 'Camera $camIndex';
          videoInputs.add(WebCameraDevice(deviceId: id, label: label));
          camIndex++;
        }
      }
      return videoInputs;
    } catch (e) {
      debugPrint('Error enumerating video devices: $e');
      return [];
    }
  }

  /// Request user media stream for a specific deviceId (or default if null)
  static Future<dynamic> startStream([String? deviceId]) async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) return null;

      final dynamic constraints;
      if (deviceId != null && deviceId.isNotEmpty) {
        constraints = {
          'video': {
            'deviceId': {'exact': deviceId},
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
          'audio': false,
        };
      } else {
        constraints = {
          'video': {
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
          'audio': false,
        };
      }

      final stream = await mediaDevices.getUserMedia(constraints);
      return stream;
    } catch (e) {
      debugPrint('Error accessing camera stream: $e');
      return null;
    }
  }

  /// Capture frame from an html.VideoElement as Uint8List JPEG bytes
  static Uint8List? captureFrame(dynamic videoElement) {
    try {
      if (videoElement is! html.VideoElement) return null;
      final width = videoElement.videoWidth > 0 ? videoElement.videoWidth : 640;
      final height = videoElement.videoHeight > 0 ? videoElement.videoHeight : 480;

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImage(videoElement, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex == -1) return null;

      final base64Data = dataUrl.substring(commaIndex + 1);
      return base64Decode(base64Data);
    } catch (e) {
      debugPrint('Error capturing frame: $e');
      return null;
    }
  }

  /// Stop all tracks in a media stream and release video element to turn off the webcam
  static void stopStream(dynamic stream, [dynamic videoElement]) {
    if (stream != null) {
      try {
        if (stream is html.MediaStream) {
          for (final track in stream.getTracks()) {
            track.stop();
          }
        }
      } catch (e) {
        debugPrint('Error stopping stream tracks: $e');
      }
    }
    if (videoElement is html.VideoElement) {
      try {
        videoElement.srcObject = null;
        videoElement.pause();
        videoElement.removeAttribute('src');
        videoElement.load();
        videoElement.remove();
      } catch (e) {
        debugPrint('Error clearing video element: $e');
      }
    }
  }

  /// Register view factory for Flutter HtmlElementView
  static void registerVideoView(String viewType, dynamic videoElement) {
    if (videoElement is html.VideoElement) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) => videoElement,
      );
    }
  }

  /// Create an HTML video element for preview with GPU layer promotion
  static dynamic createVideoElement() {
    return html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '12px'
      ..style.transform = 'translateZ(0)'
      ..style.willChange = 'transform';
  }

  /// Attach stream to video element
  static void attachStream(dynamic videoElement, dynamic stream) {
    if (videoElement is html.VideoElement && stream is html.MediaStream) {
      videoElement.srcObject = stream;
      videoElement.play().catchError((_) {});
    }
  }

  /// Open browser file picker restricted to images (jpg, jpeg, png, webp)
  /// Robust across laptops (Chrome, Edge, Safari, Firefox) and mobile web browsers.
  static Future<Uint8List?> pickImageFile({
    required Function(String errorMessage) onError,
  }) {
    final completer = Completer<Uint8List?>();
    html.FileUploadInputElement? uploadInput;

    void cleanup() {
      try {
        uploadInput?.remove();
      } catch (_) {}
    }

    try {
      uploadInput = html.FileUploadInputElement()
        ..accept = 'image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp'
        ..style.display = 'none';

      // Required by iOS Safari & modern Chrome for security validation
      html.document.body?.children.add(uploadInput);

      // Handle user cancel on supported browsers
      uploadInput.addEventListener('cancel', (e) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      });

      uploadInput.onChange.listen((e) {
        try {
          final files = uploadInput?.files;
          if (files == null || files.isEmpty) {
            cleanup();
            if (!completer.isCompleted) completer.complete(null);
            return;
          }

          final file = files[0];
          final name = file.name.toLowerCase();
          final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
          final hasAllowedExt = allowedExtensions.any((ext) => name.endsWith(ext));
          final isImageMime = file.type.isEmpty || file.type.startsWith('image/');

          if (!hasAllowedExt && !isImageMime) {
            cleanup();
            onError('Invalid format. Please select an image file (.jpg, .png, or .webp).');
            if (!completer.isCompleted) completer.complete(null);
            return;
          }

          // Enforce reasonable size limit (10MB) for web performance
          if (file.size > 10 * 1024 * 1024) {
            cleanup();
            onError('Selected image is too large (exceeds 10MB). Please select a smaller photo.');
            if (!completer.isCompleted) completer.complete(null);
            return;
          }

          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);

          reader.onLoadEnd.listen((event) {
            cleanup();
            try {
              final result = reader.result;
              if (result is Uint8List) {
                if (!completer.isCompleted) completer.complete(result);
              } else if (result is ByteBuffer) {
                if (!completer.isCompleted) completer.complete(result.asUint8List());
              } else if (result is List<int>) {
                if (!completer.isCompleted) completer.complete(Uint8List.fromList(result));
              } else {
                onError('Could not parse image data.');
                if (!completer.isCompleted) completer.complete(null);
              }
            } catch (err) {
              onError('Failed to read image data: $err');
              if (!completer.isCompleted) completer.complete(null);
            }
          });

          reader.onError.listen((event) {
            cleanup();
            onError('Error reading file from disk.');
            if (!completer.isCompleted) completer.complete(null);
          });
        } catch (err) {
          cleanup();
          onError('Error selecting image: $err');
          if (!completer.isCompleted) completer.complete(null);
        }
      });

      uploadInput.click();
    } catch (e) {
      cleanup();
      onError('Unable to open file picker: $e');
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future;
  }
}

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/web_camera_helper.dart';
import '../../../../core/widgets/app_button.dart';

class WebCameraDialog extends StatefulWidget {
  const WebCameraDialog({super.key});

  static Future<Uint8List?> show(BuildContext context) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const WebCameraDialog(),
    );
  }

  @override
  State<WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<WebCameraDialog> {
  late final String _viewType;
  late final dynamic _videoElement;
  dynamic _mediaStream;

  List<WebCameraDevice> _devices = [];
  String? _selectedDeviceId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';
    _videoElement = WebCameraHelper.createVideoElement();

    WebCameraHelper.registerVideoView(_viewType, _videoElement);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Enumerate available video inputs (laptop camera + USB webcam)
      final devices = await WebCameraHelper.getVideoDevices();
      _devices = devices;
      if (_selectedDeviceId == null && devices.isNotEmpty) {
        _selectedDeviceId = devices.first.deviceId;
      }

      // 2. Start video stream
      await _startStreamForDevice(_selectedDeviceId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to access camera: $e. Please check browser camera permissions.';
        });
      }
    }
  }

  Future<void> _startStreamForDevice(String? deviceId) async {
    WebCameraHelper.stopStream(_mediaStream);
    _mediaStream = null;

    final stream = await WebCameraHelper.startStream(deviceId);
    if (stream == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not start camera stream. Please allow browser camera access or connect a webcam.';
        });
      }
      return;
    }

    _mediaStream = stream;
    WebCameraHelper.attachStream(_videoElement, stream);

    // After starting, re-enumerate in case labels became available after permission grant
    if (_devices.isEmpty || _devices.any((d) => d.label.startsWith('Camera '))) {
      final updatedDevices = await WebCameraHelper.getVideoDevices();
      if (updatedDevices.isNotEmpty) {
        _devices = updatedDevices;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  void _onSwitchCamera(String? newDeviceId) async {
    if (newDeviceId == null || newDeviceId == _selectedDeviceId) return;
    setState(() {
      _selectedDeviceId = newDeviceId;
      _isLoading = true;
    });
    await _startStreamForDevice(newDeviceId);
  }

  void _snapPhoto() {
    final bytes = WebCameraHelper.captureFrame(_videoElement);
    if (bytes != null && bytes.isNotEmpty) {
      WebCameraHelper.stopStream(_mediaStream, _videoElement);
      _mediaStream = null;
      Navigator.of(context).pop(bytes);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture frame from camera.')),
      );
    }
  }

  @override
  void dispose() {
    WebCameraHelper.stopStream(_mediaStream, _videoElement);
    _mediaStream = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 620,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.videocam_rounded, size: 20, color: AppColors.primaryNavy),
                      SizedBox(width: 10),
                      Text(
                        'Live Webcam Face Enrollment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () {
                      WebCameraHelper.stopStream(_mediaStream);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Camera device selector row (Laptop vs USB webcam)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Camera Device:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _devices.any((d) => d.deviceId == _selectedDeviceId)
                              ? _selectedDeviceId
                              : (_devices.isNotEmpty ? _devices.first.deviceId : null),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          items: _devices.map((device) {
                            return DropdownMenuItem<String>(
                              value: device.deviceId,
                              child: Row(
                                children: [
                                  Icon(
                                    device.label.toLowerCase().contains('usb')
                                        ? Icons.usb_rounded
                                        : Icons.laptop_chromebook_rounded,
                                    size: 14,
                                    color: AppColors.accentBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      device.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _devices.length > 1 ? _onSwitchCamera : null,
                          hint: Text(
                            _devices.isEmpty ? 'Searching for webcams...' : 'Default Camera',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Live Camera Viewport
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 360,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video stream element
                      if (!_isLoading && _errorMessage == null)
                        HtmlElementView(viewType: _viewType),

                      // Loading indicator
                      if (_isLoading)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'Starting camera preview...',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                      // Error Display
                      if (_errorMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_outlined, color: Colors.redAccent, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Retry Camera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentBlue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _initializeCamera,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Facial Alignment Guide Overlay (Oval target)
                      if (!_isLoading && _errorMessage == null)
                        IgnorePointer(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 220,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(110),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    width: 2.0,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'Align face within the frame',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.outline,
                    onPressed: () {
                      WebCameraHelper.stopStream(_mediaStream);
                      Navigator.of(context).pop();
                    },
                  ),
                  AppButton(
                    label: 'Snap Portrait',
                    icon: Icons.camera,
                    variant: ButtonVariant.primary,
                    onPressed: (!_isLoading && _errorMessage == null) ? _snapPhoto : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

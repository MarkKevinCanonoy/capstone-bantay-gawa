import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows a full camera capture modal with live viewfinder preview,
/// lens switching (front/back), shutter capture, and image review.
/// Returns the temporary file path of the captured image, or null if cancelled.
Future<String?> showCameraCaptureModal(
  BuildContext context, {
  String? title,
  CameraLensDirection initialLens = CameraLensDirection.back,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => CameraCaptureModal(
      title: title ?? 'Capture Photo',
      initialLens: initialLens,
    ),
  );
}

class CameraCaptureModal extends StatefulWidget {
  final String title;
  final CameraLensDirection initialLens;

  const CameraCaptureModal({
    super.key,
    required this.title,
    this.initialLens = CameraLensDirection.back,
  });

  @override
  State<CameraCaptureModal> createState() => _CameraCaptureModalState();
}

class _CameraCaptureModalState extends State<CameraCaptureModal> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraLensDirection _currentLens = CameraLensDirection.back;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _currentLens = widget.initialLens;
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'No camera found on this device.';
          });
        }
        return;
      }

      final selectedCamera = _cameras.firstWhere(
        (c) => c.lensDirection == _currentLens,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitializing = false;
        });
      } else {
        await controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Could not access camera: $e\nPlease grant camera permissions in device settings.';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isCapturing || _isInitializing) return;

    final nextLens = _currentLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    await _controller?.dispose();
    _controller = null;

    setState(() {
      _currentLens = nextLens;
    });

    await _initCamera();
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await controller.takePicture();
      if (mounted) {
        setState(() {
          _capturedImagePath = photo.path;
          _isCapturing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImagePath = null;
    });
  }

  void _usePhoto() {
    if (_capturedImagePath != null) {
      Navigator.pop(context, _capturedImagePath);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_capturedImagePath == null && _cameras.length > 1)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 24),
                      tooltip: 'Flip Camera',
                      onPressed: _switchCamera,
                    ),
                ],
              ),
            ),

            // Viewfinder / Review Area
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildCameraBody(size),
                ),
              ),
            ),

            // Bottom Controls Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              color: Colors.black,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraBody(Size size) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.amber, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_capturedImagePath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_capturedImagePath!),
            fit: BoxFit.contain,
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.accentGreen, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Photo Preview',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isInitializing || _controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accentBlue),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.previewSize?.height ?? 300,
            height: _controller!.value.previewSize?.width ?? 400,
            child: CameraPreview(_controller!),
          ),
        ),
        // Framing guidelines overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white38, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Center subject in viewfinder & tap shutter',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    if (_capturedImagePath != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white60),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _retakePhoto,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Retake', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _usePhoto,
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Use Photo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    final isCameraReady = _controller != null && _controller!.value.isInitialized && !_isInitializing;

    return Center(
      child: GestureDetector(
        onTap: isCameraReady && !_isCapturing ? _takePicture : null,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isCameraReady ? Colors.white : Colors.white30,
              width: 4,
            ),
          ),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCameraReady ? Colors.white : Colors.white38,
              ),
              child: _isCapturing
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: AppColors.primaryNavy, strokeWidth: 3),
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: AppColors.primaryNavy, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

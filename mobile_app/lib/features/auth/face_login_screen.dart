import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/biometrics_helper.dart';
import '../../core/utils/liveness_detector.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/language_switch_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/repositories/mobile_repository_provider.dart';
import '../../data/repositories/offline_sync_service.dart';
import '../../data/repositories/supabase_mobile_repository.dart';

class FaceLoginScreen extends ConsumerStatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  ConsumerState<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends ConsumerState<FaceLoginScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isSyncingProfiles = false;
  late AnimationController _animController;
  LivenessChallenge _activeChallenge = LivenessChallenge.blink;
  String _livenessStatus = 'Ready for face verification';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _activeChallenge = LivenessDetector.getRandomChallenge();
    _initializeCamera();
    // Proactively pull newly registered workers from cloud into local SQLite
    OfflineSyncService.instance.syncInboundPersonnel();
  }

  Future<void> _manualSync() async {
    if (_isSyncingProfiles) return;
    setState(() => _isSyncingProfiles = true);
    try {
      await OfflineSyncService.instance.syncInboundPersonnel();
      if (mounted) {
        ToastNotification.showSuccess(context, 'Enrolled profiles updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(context, 'Profile sync notice: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncingProfiles = false);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera initialization error (using fallback preview): $e');
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _handleFaceScan() async {
    if (_isProcessing) return;

    if (_cameraController == null || !_isCameraReady) {
      if (mounted) {
        ToastNotification.showError(
          context,
          'Camera is not ready. Please allow camera permissions and try again.',
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _livenessStatus = 'Verifying...';
    });

    try {
      setState(() => _livenessStatus = 'Capturing...');

      // Step 1: Capture live photo from camera
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();

      if (imageBytes.isEmpty) {
        if (mounted) {
          ToastNotification.showError(context, 'Failed to capture photo from camera.');
        }
        return;
      }

      setState(() => _livenessStatus = 'Checking liveness...');

      // Step 2: Anti-spoofing verification (detects glass/picture frame reflection & printed photo)
      final liveness = await LivenessDetector.evaluateImageLiveness(imageBytes);
      if (!liveness.isLive) {
        if (mounted) {
          ToastNotification.showError(
            context,
            liveness.errorMessage ?? 'Human presence not detected. Try again.',
          );
        }
        return;
      }

      setState(() => _livenessStatus = 'Scanning face...');

      // Step 3: Extract normalized 512-dimensional facial embedding vector
      final faceVector = BiometricsHelper.extractFeatureVector(imageBytes);

      setState(() => _livenessStatus = 'Matching record...');

      // Step 4: Facial vector comparison against registered DB embeddings
      final success = await ref
          .read(currentUserProvider.notifier)
          .loginWithFace(faceVector)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );
      if (!mounted) return;

      if (success) {
        ToastNotification.showSuccess(context, 'Verified. Welcome!');
      } else {
        final repo = ref.read(mobileRepositoryProvider);
        if (repo is SupabaseMobileRepository) {
          final count = repo.lastCandidateCount;
          final sim = repo.lastMatchSimilarity;
          if (count == 0) {
            ToastNotification.showError(
              context,
              'No enrolled profiles on device. Tap the sync button at top or connect to internet.',
            );
          } else if (sim > 0) {
            final pct = (sim * 100).toInt();
            ToastNotification.showError(
              context,
              'Face match was $pct% (needed 65%). Look directly into the circle with good lighting.',
            );
          } else {
            ToastNotification.showError(
              context,
              'Face not recognized ($count profiles checked). Ensure face is centered inside circle.',
            );
          }
        } else {
          ToastNotification.showError(
            context,
            'Face not recognized. Please ensure you are enrolled as active personnel.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
        ToastNotification.showError(context, cleanMsg.isNotEmpty ? cleanMsg : 'Verification error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _livenessStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final challengePrompt = lang == AppLanguage.cebuano
        ? _activeChallenge.instructionsCebuano
        : _activeChallenge.instructionsEnglish;

    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final isSmallScreen = screenHeight < 680;
            final circleSize = (screenHeight * 0.30).clamp(160.0, 240.0);

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Top Bar with Official Logo, Manual Sync, and Language Switcher
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppLogo(compact: true, isDark: true),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Sync Enrolled Profiles',
                                  icon: _isSyncingProfiles
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                        )
                                      : const Icon(Icons.sync_rounded, size: 20, color: Colors.white70),
                                  onPressed: _isSyncingProfiles ? null : _manualSync,
                                ),
                                const SizedBox(width: 4),
                                const LanguageSwitchButton(isDark: true, compact: true),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 20),
                        const Spacer(),

                        // Circular Face Scanner Viewfinder (Preserving 100% natural aspect ratio)
                        Center(
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              return Container(
                                width: circleSize,
                                height: circleSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isProcessing
                                        ? AppColors.accentGreen
                                        : Color.lerp(
                                            AppColors.accentBlue,
                                            AppColors.accentGreen,
                                            _animController.value,
                                          )!,
                                    width: 3.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentBlue.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _isCameraReady && _cameraController != null
                                      ? LayoutBuilder(
                                          builder: (context, constraints) {
                                            final double rawRatio = _cameraController!.value.aspectRatio;
                                            final double portraitRatio =
                                                rawRatio > 1.0 ? (1.0 / rawRatio) : rawRatio;
                                            return SizedBox(
                                              width: constraints.maxWidth,
                                              height: constraints.maxHeight,
                                              child: FittedBox(
                                                fit: BoxFit.cover,
                                                child: SizedBox(
                                                  width: 100,
                                                  height: 100 / portraitRatio,
                                                  child: CameraPreview(_cameraController!),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: const Color(0xFF0F172A),
                                          child: Center(
                                            child: Icon(
                                              Icons.face,
                                              size: circleSize * 0.35,
                                              color: const Color(0xFF6CC5FF),
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 12 : 16),
                        // Minimal instruction chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isProcessing
                                ? (_livenessStatus.isNotEmpty
                                    ? _livenessStatus
                                    : AppTranslations.get('verifying_biometrics', lang))
                                : challengePrompt,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 10 : 14),
                        Text(
                          AppTranslations.get('biometric_login_title', lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppTranslations.get('biometric_login_desc', lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isSmallScreen ? 12 : 13,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(height: isSmallScreen ? 12 : 20),

                        // Action Button
                        AppButton(
                          label: _isProcessing
                              ? AppTranslations.get('verifying_biometrics', lang)
                              : AppTranslations.get('scan_face_login', lang),
                          icon: Icons.camera_alt_outlined,
                          isLoading: _isProcessing,
                          variant: AppButtonVariant.success,
                          minHeight: isSmallScreen ? 48 : 52,
                          onPressed: _isProcessing ? null : _handleFaceScan,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


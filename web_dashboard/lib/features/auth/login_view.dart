import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

enum MfaStep {
  credentials,
  otp,
  face,
}

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> with SingleTickerProviderStateMixin {
  MfaStep _currentStep = MfaStep.credentials;
  bool _isLoading = false;

  // Step 1: Credentials
  final _usernameController = TextEditingController(text: 'admin_enro');
  final _passwordController = TextEditingController(text: 'Admin@1234');
  bool _obscurePassword = true;

  // Step 2: OTP
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  // Step 3: Biometric Face Verification
  bool _isScanning = false;
  double _scanProgress = 0.0;
  bool _faceVerified = false;
  Timer? _scanTimer;
  late AnimationController _scannerAnimController;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _countdownTimer?.cancel();
    _scanTimer?.cancel();
    _scannerAnimController.dispose();
    super.dispose();
  }

  // --- Step 1: Submit Credentials ---
  void _handleCredentialsSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      ToastNotification.show(context, message: 'Please enter your Username or Admin ID.', type: ToastType.error);
      return;
    }
    if (password.isEmpty) {
      ToastNotification.show(context, message: 'Please enter your Password.', type: ToastType.error);
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Populate demo OTP code (582910 from SRS prototype)
    const demoOtp = ['5', '8', '2', '9', '1', '0'];
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].text = demoOtp[i];
    }

    setState(() {
      _currentStep = MfaStep.otp;
    });

    _startResendCountdown();

    ToastNotification.show(
      context,
      message: 'Step 1 Passed. 6-digit MFA OTP sent to registered email.',
      type: ToastType.info,
    );
  }

  // --- Step 2: OTP Countdown & Submit ---
  void _startResendCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  void _handleResendOtp() {
    if (_resendCountdown > 0) return;
    _startResendCountdown();
    ToastNotification.show(
      context,
      message: 'New security OTP sent to ${_usernameController.text}@enro.ormoc.gov.ph (Code: 582910)',
      type: ToastType.info,
    );
  }

  void _handleOtpSubmit() async {
    final otpCode = _otpControllers.map((c) => c.text.trim()).join();
    if (otpCode.length < 6) {
      ToastNotification.show(context, message: 'Please enter the complete 6-digit OTP code.', type: ToastType.error);
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isLoading = false);

    setState(() {
      _currentStep = MfaStep.face;
    });

    ToastNotification.show(
      context,
      message: 'Step 2 Passed. Initializing on-device Biometric Verification (MobileFaceNet)...',
      type: ToastType.info,
    );

    // Auto-trigger biometric face scan
    _startBiometricScan();
  }

  // --- Step 3: Biometric Face Verification (MobileFaceNet Simulation) ---
  void _startBiometricScan() {
    _scanTimer?.cancel();
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _faceVerified = false;
    });

    const totalTicks = 20;
    int tick = 0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) return;
      tick++;
      setState(() {
        _scanProgress = tick / totalTicks;
      });

      if (tick >= totalTicks) {
        timer.cancel();
        setState(() {
          _isScanning = false;
          _faceVerified = true;
        });

        ToastNotification.show(
          context,
          message: 'Biometric Face Verified! Cosine Similarity: 98.6% (Pass Threshold >= 85.0%).',
          type: ToastType.success,
        );

        // Auto-redirect to dashboard within <= 3 seconds (SRS Acceptance Criteria)
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          _completeLogin(
            isSupervisor: _usernameController.text.toLowerCase().contains('sup'),
          );
        });
      }
    });
  }

  void _completeLogin({required bool isSupervisor}) {
    if (isSupervisor) {
      ref.read(currentUserProvider.notifier).state = UserModel(
        userId: '22222222-2222-2222-2222-222222222222',
        username: 'sup_juan',
        firstName: 'Juan',
        lastName: 'Santos',
        contactNumber: '+63 917 222 0002',
        role: UserRole.supervisor,
        status: 'active',
        assignedAreaId: '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        assignedAreaName: 'Downtown Commercial Corridor',
      );
    } else {
      ref.read(currentUserProvider.notifier).state = UserModel(
        userId: '11111111-1111-1111-1111-111111111111',
        username: 'admin_enro',
        firstName: 'Roberto',
        lastName: 'Del Rosario',
        contactNumber: '+63 917 111 0001',
        role: UserRole.admin,
        status: 'active',
      );
    }

    ref.read(activeNavProvider.notifier).state = 'dashboard';
    ToastNotification.show(
      context,
      message: isSupervisor
          ? 'Welcome, Field Supervisor Juan Santos!'
          : 'Authenticated successfully as System Administrator Roberto Del Rosario!',
      type: ToastType.success,
    );
  }

  // --- Fast Demo Logins ---
  void _demoLoginAs(UserRole role) {
    _completeLogin(isSupervisor: role == UserRole.supervisor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Container(
            width: 460,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Brand Accent Bar
                Container(
                  height: 6,
                  color: AppColors.primaryNavy,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo & Seal
                      _buildHeader(),

                      const SizedBox(height: 24),

                      // Stepper: [1] Credentials -> [2] OTP Code -> [3] Face Match
                      _buildStepper(),

                      const SizedBox(height: 28),

                      // Dynamic Step Content
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildCurrentStepContent(),
                      ),

                      const SizedBox(height: 28),

                      // Demo Quick Access Bar
                      _buildDemoQuickAccess(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryNavy.withValues(alpha: 0.15),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNavy.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'images/official_seal.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.primaryNavy,
              child: const Icon(Icons.shield, color: Colors.white, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'BantayGawa Portal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Intelligent Workforce Verification System\nEnvironment and Natural Resources Office (ENRO)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // --- Visual 3-Step Breadcrumb / Stepper ---
  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildStepPill(
            index: 1,
            title: 'Credentials',
            isCurrent: _currentStep == MfaStep.credentials,
            isDone: _currentStep == MfaStep.otp || _currentStep == MfaStep.face,
          ),
          _buildStepDivider(isDone: _currentStep == MfaStep.otp || _currentStep == MfaStep.face),
          _buildStepPill(
            index: 2,
            title: 'OTP Code',
            isCurrent: _currentStep == MfaStep.otp,
            isDone: _currentStep == MfaStep.face,
          ),
          _buildStepDivider(isDone: _currentStep == MfaStep.face),
          _buildStepPill(
            index: 3,
            title: 'Face Match',
            isCurrent: _currentStep == MfaStep.face,
            isDone: _faceVerified,
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill({
    required int index,
    required String title,
    required bool isCurrent,
    required bool isDone,
  }) {
    Color bg;
    Widget icon;

    if (isDone) {
      bg = AppColors.accentEmerald;
      icon = const Icon(Icons.check, size: 12, color: Colors.white);
    } else if (isCurrent) {
      bg = AppColors.primaryNavy;
      icon = Text(
        '$index',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    } else {
      bg = Colors.white;
      icon = Text(
        '$index',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight),
      );
    }

    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: isDone || isCurrent ? null : Border.all(color: AppColors.border),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent
                    ? AppColors.primaryNavy
                    : isDone
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider({required bool isDone}) {
    return Container(
      width: 14,
      height: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDone ? AppColors.accentEmerald : AppColors.border,
    );
  }

  // --- Step Router ---
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case MfaStep.credentials:
        return _buildStep1Credentials();
      case MfaStep.otp:
        return _buildStep2Otp();
      case MfaStep.face:
        return _buildStep3FaceMatch();
    }
  }

  // =========================================================================
  // STEP 1: CREDENTIALS (SOMETHING YOU KNOW)
  // =========================================================================
  Widget _buildStep1Credentials() {
    return KeyedSubtree(
      key: const ValueKey('step1_credentials'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navActiveBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, size: 18, color: AppColors.accentBlue),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 1 of 3: Primary Credentials',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Enter your registered administrative credentials',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Username Field
          const Text(
            'Username or Email',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline, size: 18, color: AppColors.textMuted),
              hintText: 'Enter username (e.g. admin_enro)',
            ),
          ),
          const SizedBox(height: 16),

          // Password Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              InkWell(
                onTap: () {
                  ToastNotification.show(
                    context,
                    message: 'Password reset link sent to registered email address.',
                    type: ToastType.info,
                  );
                },
                child: const Text(
                  'Forgot?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
              hintText: 'Enter password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          const SizedBox(height: 24),

          AppButton(
            label: 'Continue to MFA Verification',
            icon: Icons.arrow_forward_rounded,
            isLoading: _isLoading,
            onPressed: _handleCredentialsSubmit,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 2: TIME-SENSITIVE OTP (SOMETHING YOU HAVE)
  // =========================================================================
  Widget _buildStep2Otp() {
    final emailDisplay = '${_usernameController.text}@enro.ormoc.gov.ph';

    return KeyedSubtree(
      key: const ValueKey('step2_otp'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.statusOptimalBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.key_rounded, size: 18, color: AppColors.statusOptimalText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 2 of 3: Secure Email OTP',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Code sent to $emailDisplay',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 6-Digit OTP Box Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 48,
                height: 52,
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: AppColors.surfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && index < 5) {
                      _otpFocusNodes[index + 1].requestFocus();
                    } else if (val.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Resend Countdown
          Center(
            child: _resendCountdown > 0
                ? Text(
                    'Resend code in ${_resendCountdown}s',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  )
                : InkWell(
                    onTap: _handleResendOtp,
                    child: const Text(
                      'Didn\'t receive code? Resend OTP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentBlue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          AppButton(
            label: 'Verify OTP Code',
            icon: Icons.check_circle_outline,
            isLoading: _isLoading,
            onPressed: _handleOtpSubmit,
          ),

          const SizedBox(height: 10),

          // Back to Step 1
          TextButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Login Credentials'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
            ),
            onPressed: () => setState(() => _currentStep = MfaStep.credentials),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 3: BIOMETRIC FACE VERIFICATION (SOMETHING YOU ARE)
  // =========================================================================
  Widget _buildStep3FaceMatch() {
    final userName = _usernameController.text.toLowerCase().contains('sup')
        ? 'Juan Santos (Field Supervisor)'
        : 'Roberto Del Rosario (System Administrator)';

    return KeyedSubtree(
      key: const ValueKey('step3_face'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _faceVerified ? AppColors.successBg : AppColors.statusOptimalBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _faceVerified ? Icons.verified_user : Icons.face,
                  size: 18,
                  color: _faceVerified ? AppColors.successText : AppColors.statusOptimalText,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 3 of 3: Biometric Face Match',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Text(
                    'MobileFaceNet on-device cosine vector similarity',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Face Scan Radar Viewport
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _faceVerified
                    ? AppColors.accentEmerald
                    : _isScanning
                        ? AppColors.accentBlue
                        : AppColors.border,
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Targeting Reticle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _faceVerified
                          ? AppColors.accentEmerald
                          : Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                ),

                // Icon in viewport
                Icon(
                  _faceVerified
                      ? Icons.check_circle_rounded
                      : Icons.face_retouching_natural_rounded,
                  size: 64,
                  color: _faceVerified
                      ? AppColors.accentEmerald
                      : Colors.white.withValues(alpha: 0.85),
                ),

                // Animated Scan Beam
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _scannerAnimController,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + (_scannerAnimController.value * 140),
                        left: 24,
                        right: 24,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentBlue.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, AppColors.accentBlue, Colors.transparent],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Match Badge Overlay
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _faceVerified
                          ? AppColors.accentEmerald
                          : Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _faceVerified
                          ? 'Cosine Match: 98.6% (VERIFIED)'
                          : _isScanning
                              ? 'Scanning Face Embedding... ${(_scanProgress * 100).toInt()}%'
                              : 'Target Face In Frame',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // User Bio Identity Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, size: 20, color: AppColors.primaryNavy),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Registered Profile:',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                if (_faceVerified)
                  const Icon(Icons.verified, size: 20, color: AppColors.accentEmerald),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          if (!_faceVerified) ...[
            AppButton(
              label: _isScanning ? 'Verifying...' : 'Perform Biometric Match',
              icon: Icons.camera_front_rounded,
              isLoading: _isScanning,
              onPressed: _isScanning ? null : _startBiometricScan,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to OTP Code'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _currentStep = MfaStep.otp),
            ),
          ] else ...[
            AppButton(
              label: 'Launching Dashboard...',
              icon: Icons.check,
              variant: ButtonVariant.accent,
              onPressed: () => _completeLogin(
                isSupervisor: _usernameController.text.toLowerCase().contains('sup'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // DEMO QUICK ACCESS (FOR FASTER TESTING)
  // =========================================================================
  Widget _buildDemoQuickAccess() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'DEMO QUICK-ACCESS',
                style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Admin Portal',
                icon: Icons.admin_panel_settings,
                variant: ButtonVariant.secondary,
                onPressed: () => _demoLoginAs(UserRole.admin),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Supervisor',
                icon: Icons.shield_outlined,
                variant: ButtonVariant.secondary,
                onPressed: () => _demoLoginAs(UserRole.supervisor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


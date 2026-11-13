import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/auth_config.dart';
import '../../core/utils/webauthn_helper.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/passkey_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/repositories/mock_repository.dart';

enum AuthViewMode {
  login,
  firstTimeSetup,
  forgotPassword,
}

enum RecoveryStep {
  enterEmail,
  verifyOtp,
  setPassword,
  enrollBiometrics,
}

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  AuthViewMode _viewMode = AuthViewMode.login;
  RecoveryStep _recoveryStep = RecoveryStep.enterEmail;

  // Controllers for Standard Login
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  // Controllers for Activation & Forgot Password
  final _recoveryEmailController = TextEditingController();
  final _recoveryOtpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _lastSentEmail = '';
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _showOtp = false;
  bool _isLoading = false;
  bool _isBiometricSupported = false;
  bool _isEnrollingBiometric = false;

  UserModel? _pendingUser;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    if (mounted) setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _checkBiometrics();
  }

  void _checkBiometrics() async {
    final avail = await WebAuthnHelper.isPlatformBiometricAvailable();
    if (mounted) {
      setState(() => _isBiometricSupported = avail);
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _recoveryEmailController.dispose();
    _recoveryOtpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Password Strength Criteria
  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasUppercase => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _newPasswordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=~`]'));
  bool get _passwordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  bool get _isPasswordValid =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasDigit && _hasSpecial && _passwordsMatch;

  int get _strengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasDigit) score++;
    if (_hasSpecial) score++;
    return score;
  }

  String get _strengthLabel {
    final score = _strengthScore;
    if (score <= 1) return 'Weak';
    if (score <= 3) return 'Fair';
    if (score == 4) return 'Good';
    return 'Strong';
  }

  Color get _strengthColor {
    final score = _strengthScore;
    if (score <= 1) return AppColors.brightRed;
    if (score <= 3) return const Color(0xFFD97706);
    if (score == 4) return AppColors.accentBlue;
    return AppColors.accentEmerald;
  }

  bool _isSecretAdminDemo(String input) => AuthConfig.isDemoAccount(input);

  // ==========================================
  // Quick Biometric (Passkey / WebAuthn) Login Flow
  // ==========================================
  void _handleQuickBiometricLogin() async {
    setState(() => _isLoading = true);
    try {
      final randomBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final challenge = base64UrlEncode(randomBytes);

      final authResult = await WebAuthnHelper.authenticateBiometric(
        challengeBase64: challenge,
      );

      if (!authResult.success) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: authResult.error ?? 'Biometric verification cancelled.',
            type: ToastType.info,
          );
        }
        return;
      }

      final credId = authResult.credentialId;
      if (credId == null || credId.isEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'No credential returned from biometric sensor.',
            type: ToastType.error,
          );
        }
        return;
      }

      final repo = ref.read(dataRepositoryProvider);
      final user = await repo.findUserByPasskeyCredential(credId);

      if (user == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Biometric recognized, but no account is registered to this device yet. Please log in with your email and password first.',
            type: ToastType.warning,
          );
        }
        return;
      }

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Biometrics verified! Welcome back, ${user.fullName}.',
          type: ToastType.success,
        );
      }

      await _completeLogin(user.username, isDemo: false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Biometric sign-in error: $e',
          type: ToastType.error,
        );
      }
    }
  }

  // ==========================================
  // Standard Login Flow
  // ==========================================
  void _handleLogin() async {
    final inputUser = _usernameController.text.trim();
    final inputPassword = _passwordController.text;
    _lastSentEmail = inputUser;

    if (inputUser.isEmpty) {
      ToastNotification.show(
        context,
        message: 'Please enter your username or email.',
        type: ToastType.error,
      );
      return;
    }

    if (inputPassword.isEmpty && !_showOtp) {
      ToastNotification.show(
        context,
        message: 'Please enter your password.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    final cleanInput = inputUser.toLowerCase();
    final isSecretAdminDemo = _isSecretAdminDemo(cleanInput);
    final isMock = ref.read(dataRepositoryProvider) is MockRepository;

    // --- STEP 2: VERIFY OTP ---
    if (_showOtp) {
      final otpCode = _otpController.text.trim().replaceAll(RegExp(r'[\s\-]+'), '');
      if (otpCode.isEmpty ||
          ((otpCode.length < 6 || otpCode.length > 10) &&
              !(isMock && (otpCode == '123456' || otpCode == '000000' || otpCode == '12345678')))) {
        setState(() => _isLoading = false);
        ToastNotification.show(
          context,
          message: 'Enter verification code.',
          type: ToastType.error,
        );
        return;
      }

      if (isSecretAdminDemo || (isMock && (otpCode == '123456' || otpCode == '000000' || otpCode == '12345678'))) {
        await _completeLogin(cleanInput, isDemo: isSecretAdminDemo);
        return;
      }

      try {
        AuthResponse res;
        try {
          res = await Supabase.instance.client.auth.verifyOTP(
            type: OtpType.email,
            token: otpCode,
            email: _lastSentEmail,
          );
        } on AuthException {
          try {
            res = await Supabase.instance.client.auth.verifyOTP(
              type: OtpType.recovery,
              token: otpCode,
              email: _lastSentEmail,
            );
          } catch (_) {
            rethrow;
          }
        }

        if (res.session == null && res.user == null) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ToastNotification.show(
            context,
            message: 'Invalid verification code. Please check your email.',
            type: ToastType.error,
          );
          return;
        }
      } on AuthException catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          final errLower = e.message.toLowerCase();
          final msg = errLower.contains('expired')
              ? 'Verification code expired. Please click "Resend code".'
              : (errLower.contains('invalid')
                  ? 'Invalid verification code. Please check your email or click "Resend code".'
                  : e.message);
          ToastNotification.show(context, message: msg, type: ToastType.error);
        }
        return;
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(context, message: 'Verification error: $e', type: ToastType.error);
        }
        return;
      }

      await _completeLogin(cleanInput, isDemo: false);
      return;
    }

    // --- STEP 1: VERIFY PRIMARY CREDENTIALS & DISPATCH OTP ---
    try {
      final repo = ref.read(dataRepositoryProvider);
      final users = await repo.getUsers();

      final matched = users.where((u) =>
        u.username.toLowerCase() == cleanInput ||
        (u.username.contains('@') && u.username.toLowerCase() == cleanInput)
      ).toList();

      if (matched.isEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Account not found in ENRO personnel database. Please check credentials or contact administrator.',
            type: ToastType.error,
          );
        }
        return;
      }

      final foundUser = matched.first;

      // 1. Check if account is still pending activation
      if (foundUser.status == 'pending' && foundUser.role == UserRole.supervisor) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'This supervisor account has not been activated yet. Please click "First-Time Supervisor? Activate Account" below.',
            type: ToastType.warning,
          );
        }
        return;
      }

      // 2. Check if account is suspended / inactive
      if (foundUser.status == 'inactive' || foundUser.status == 'suspended') {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'This account has been deactivated. Please contact the administrator.',
            type: ToastType.error,
          );
        }
        return;
      }

      // 3. Modular Demo Account Bypass (markkevincanonoy99@gmail.com):
      if (isSecretAdminDemo) {
        await _completeLogin(cleanInput, isDemo: true);
        return;
      }

      // 4. FACTOR 1: Primary Password Verification via Supabase Auth
      final targetAuthEmail = foundUser.username.contains('@') ? foundUser.username : cleanInput;
      if (repo is! MockRepository) {
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: targetAuthEmail,
            password: inputPassword,
          );
        } on AuthException catch (authErr) {
          setState(() => _isLoading = false);
          if (mounted) {
            final errLower = authErr.message.toLowerCase();
            final msg = (errLower.contains('invalid') || errLower.contains('credentials'))
                ? 'Incorrect password. Please verify your credentials or click "Forgot Password?".'
                : (errLower.contains('email not confirmed')
                    ? 'Account email is not confirmed. Please activate your account first.'
                    : authErr.message);
            ToastNotification.show(
              context,
              message: msg,
              type: ToastType.error,
            );
          }
          return;
        } catch (err) {
          setState(() => _isLoading = false);
          if (mounted) {
            ToastNotification.show(
              context,
              message: 'Authentication error: $err',
              type: ToastType.error,
            );
          }
          return;
        }
      } else {
        // MockRepository behavior for unit testing
        if (inputPassword == 'wrong_password') {
          setState(() => _isLoading = false);
          if (mounted) {
            ToastNotification.show(
              context,
              message: 'Incorrect password. Please verify your credentials or click "Forgot Password?".',
              type: ToastType.error,
            );
          }
          return;
        }
      }

      // 5. FACTOR 2: Enforce Multi-Factor Authentication via Real OTP (SRS FR-01)
      try {
        await Supabase.instance.client.auth.signInWithOtp(email: targetAuthEmail);
        _startCooldown(60);
        setState(() {
          _isLoading = false;
          _showOtp = true;
          _lastSentEmail = targetAuthEmail;
        });
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Password verified! A verification code was sent to $targetAuthEmail.',
            type: ToastType.success,
          );
        }
      } on AuthException catch (authErr) {
        setState(() => _isLoading = false);
        if (mounted) {
          final errLower = authErr.message.toLowerCase();
          final msg = (errLower.contains('rate') || errLower.contains('second') || errLower.contains('frequency'))
              ? 'For security, please wait a minute before requesting another verification code.'
              : 'Could not send verification code: ${authErr.message}';
          ToastNotification.show(
            context,
            message: msg,
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Authentication error: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _completeLogin(String cleanInput, {bool isDemo = false}) async {
    final repo = ref.read(dataRepositoryProvider);
    final users = await repo.getUsers();

    final matched = users.where((u) =>
      u.username.toLowerCase() == cleanInput ||
      (u.username.contains('@') && u.username.toLowerCase() == cleanInput)
    ).toList();

    final loggedInUser = matched.isNotEmpty
        ? matched.first
        : UserModel(
            userId: Supabase.instance.client.auth.currentUser?.id ?? '11111111-1111-1111-1111-111111111111',
            username: cleanInput,
            firstName: 'Mark Kevin',
            lastName: 'Canonoy',
            contactNumber: '+63 917 555 0199',
            role: UserRole.admin,
            status: 'active',
            schedule: 'Unassigned',
          );

    setState(() => _isLoading = false);
    ref.read(currentUserProvider.notifier).state = loggedInUser;
    if (loggedInUser.role == UserRole.admin) {
      ref.read(lastActiveAdminProvider.notifier).state = loggedInUser;
    }
    ref.read(activeNavProvider.notifier).state = 'dashboard';

    if (mounted) {
      final welcomeMsg = isDemo
          ? 'Welcome back, ${loggedInUser.firstName}! (Demo Mode - OTP bypassed)'
          : 'Welcome back, ${loggedInUser.firstName}!';
      ToastNotification.show(context, message: welcomeMsg, type: ToastType.success);
    }
  }

  void _resendOtp() async {
    if (_cooldownSeconds > 0) {
      ToastNotification.show(
        context,
        message: 'Please wait ${_cooldownSeconds}s before requesting a new code.',
        type: ToastType.info,
      );
      return;
    }

    final inputUser = _lastSentEmail.isNotEmpty ? _lastSentEmail : _usernameController.text.trim();
    if (inputUser.isEmpty) return;

    if (_isSecretAdminDemo(inputUser)) {
      ToastNotification.show(
        context,
        message: 'Demo Account recognized: OTP skipped.',
        type: ToastType.success,
      );
      return;
    }

    if (ref.read(dataRepositoryProvider) is MockRepository) {
      _startCooldown(60);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Verification code resent to $inputUser (Test mode).',
          type: ToastType.info,
        );
      }
      return;
    }

    try {
      await Supabase.instance.client.auth.signInWithOtp(email: inputUser);
      _startCooldown(60);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Verification code resent to $inputUser. Please check your inbox and spam folder.',
          type: ToastType.success,
        );
      }
    } on AuthException catch (authErr) {
      if (mounted) {
        final errLower = authErr.message.toLowerCase();
        final msg = (errLower.contains('rate') || errLower.contains('second') || errLower.contains('frequency'))
            ? 'For security, please wait a minute before requesting another verification code.'
            : 'Could not send verification code: ${authErr.message}';
        ToastNotification.show(context, message: msg, type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(context, message: 'Could not send verification code: $e', type: ToastType.error);
      }
    }
  }

  // ==========================================
  // First-Time Activation & Password Recovery Flow
  // ==========================================
  void _handleSendRecoveryOtp() async {
    final email = _recoveryEmailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ToastNotification.show(context, message: 'Please enter your registered email address.', type: ToastType.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(dataRepositoryProvider);
      final users = await repo.getUsers();

      final matched = users.where((u) =>
        u.username.toLowerCase() == email ||
        (u.username.contains('@') && u.username.toLowerCase() == email)
      ).toList();

      if (matched.isEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'No personnel record found for $email. Please verify your address or contact Central Admin.',
            type: ToastType.error,
          );
        }
        return;
      }

      final user = matched.first;
      _pendingUser = user;

      // Status check
      if (user.status == 'inactive' || user.status == 'suspended') {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Your account is currently inactive. Please contact Central Admin.',
            type: ToastType.error,
          );
        }
        return;
      }

      // Role check
      if (user.role != UserRole.supervisor && user.role != UserRole.admin) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Field Workers authenticate via ID QR badge scan on mobile (SRS UC-14). Web portal access is for Supervisors and Admins.',
            type: ToastType.warning,
          );
        }
        return;
      }

      // Mode-specific guards
      if (_viewMode == AuthViewMode.firstTimeSetup) {
        if (user.status == 'active') {
          setState(() => _isLoading = false);
          if (mounted) {
            ToastNotification.show(
              context,
              message: 'Account is already activated! Please log in, or click "Forgot Password?" to reset your credentials.',
              type: ToastType.info,
            );
          }
          return;
        }
      }

      if (_viewMode == AuthViewMode.forgotPassword) {
        if (user.status == 'pending') {
          setState(() => _isLoading = false);
          if (mounted) {
            ToastNotification.show(
              context,
              message: 'This supervisor account has not been activated yet. Please click "First-Time Supervisor? Activate Account".',
              type: ToastType.warning,
            );
          }
          return;
        }
      }

      // Secret Admin Test Account: Skip sending OTP completely and jump straight to setting password
      if (_isSecretAdminDemo(email)) {
        setState(() {
          _isLoading = false;
          _recoveryStep = RecoveryStep.setPassword;
          _lastSentEmail = email;
        });
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Demo Account recognized: OTP skipped.',
            type: ToastType.success,
          );
        }
        return;
      }

      // FOR ALL OTHER ACCOUNTS (SUPERVISOR ACTIVATION & FORGOT PASSWORD):
      try {
        await Supabase.instance.client.auth.signInWithOtp(email: email);
        _startCooldown(60);
        setState(() {
          _isLoading = false;
          _recoveryStep = RecoveryStep.verifyOtp;
          _lastSentEmail = email;
        });
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'A verification code has been dispatched to $email. Please check your inbox and spam folder.',
            type: ToastType.success,
          );
        }
      } on AuthException catch (authErr) {
        setState(() => _isLoading = false);
        if (mounted) {
          final errLower = authErr.message.toLowerCase();
          final msg = (errLower.contains('rate') || errLower.contains('second') || errLower.contains('frequency'))
              ? 'For security, please wait a minute before requesting another verification code.'
              : 'Could not send verification code: ${authErr.message}';
          ToastNotification.show(context, message: msg, type: ToastType.error);
        }
      } catch (err) {
        // Fallback for mock test environments where Supabase is not initialized
        if (ref.read(dataRepositoryProvider) is MockRepository) {
          _startCooldown(60);
          setState(() {
            _isLoading = false;
            _recoveryStep = RecoveryStep.verifyOtp;
            _lastSentEmail = email;
          });
          if (mounted) {
            ToastNotification.show(
              context,
              message: 'Verification code dispatched to $email (Test mode).',
              type: ToastType.info,
            );
          }
          return;
        }
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Failed to dispatch verification email: $err',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Service error: $e', type: ToastType.error);
      }
    }
  }

  void _resendRecoveryOtp() async {
    if (_cooldownSeconds > 0) {
      ToastNotification.show(
        context,
        message: 'Please wait ${_cooldownSeconds}s before requesting a new code.',
        type: ToastType.info,
      );
      return;
    }

    final targetEmail = _lastSentEmail.isNotEmpty
        ? _lastSentEmail
        : _recoveryEmailController.text.trim().toLowerCase();

    if (targetEmail.isEmpty) {
      ToastNotification.show(
        context,
        message: 'Please enter your registered email address first.',
        type: ToastType.error,
      );
      return;
    }

    if (_isSecretAdminDemo(targetEmail)) {
      ToastNotification.show(
        context,
        message: 'Demo Account recognized: OTP skipped.',
        type: ToastType.success,
      );
      return;
    }

    if (ref.read(dataRepositoryProvider) is MockRepository) {
      _startCooldown(60);
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'A fresh verification code was sent to $targetEmail (Test mode).',
          type: ToastType.info,
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(email: targetEmail);
      _startCooldown(60);
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'A fresh verification code was sent to $targetEmail. Please check your inbox and spam folder.',
          type: ToastType.success,
        );
      }
    } on AuthException catch (authErr) {
      setState(() => _isLoading = false);
      if (mounted) {
        final errLower = authErr.message.toLowerCase();
        final msg = (errLower.contains('rate') || errLower.contains('second') || errLower.contains('frequency'))
            ? 'For security, please wait a minute before requesting another verification code.'
            : 'Could not resend code: ${authErr.message}';
        ToastNotification.show(context, message: msg, type: ToastType.error);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Could not resend code: $e', type: ToastType.error);
      }
    }
  }

  void _handleVerifyRecoveryOtp() async {
    final otp = _recoveryOtpController.text.trim().replaceAll(RegExp(r'[\s\-]+'), '');
    final isMockRepo = ref.read(dataRepositoryProvider) is MockRepository;
    if (otp.isEmpty ||
        ((otp.length < 6 || otp.length > 10) &&
            !(isMockRepo && (otp == '123456' || otp == '000000' || otp == '12345678')))) {
      ToastNotification.show(context, message: 'Enter verification code.', type: ToastType.error);
      return;
    }

    setState(() => _isLoading = true);
    final email = _lastSentEmail.toLowerCase();

    // Unit test bypass for MockRepository
    if (isMockRepo && (otp == '123456' || otp == '000000' || otp == '12345678')) {
      setState(() {
        _isLoading = false;
        _recoveryStep = RecoveryStep.setPassword;
      });
      ToastNotification.show(context, message: 'Identity confirmed! Please create your new secure password.', type: ToastType.success);
      return;
    }

    // REAL OTP VERIFICATION VIA SUPABASE
    try {
      AuthResponse res;
      try {
        res = await Supabase.instance.client.auth.verifyOTP(
          type: OtpType.email,
          token: otp,
          email: email,
        );
      } on AuthException {
        try {
          res = await Supabase.instance.client.auth.verifyOTP(
            type: OtpType.recovery,
            token: otp,
            email: email,
          );
        } catch (_) {
          rethrow;
        }
      }

      if (res.session == null && res.user == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastNotification.show(context, message: 'Invalid or expired verification code. Please check your inbox and spam folder.', type: ToastType.error);
        }
        return;
      }

      setState(() {
        _isLoading = false;
        _recoveryStep = RecoveryStep.setPassword;
      });
      if (mounted) {
        ToastNotification.show(context, message: 'Identity confirmed! Please create your new secure password.', type: ToastType.success);
      }
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final errLower = e.message.toLowerCase();
        final msg = errLower.contains('expired')
            ? 'Verification code expired. Please click "Resend code".'
            : (errLower.contains('invalid')
                ? 'Invalid verification code. Please verify the passcode in your email.'
                : e.message);
        ToastNotification.show(context, message: msg, type: ToastType.error);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Verification error: $e', type: ToastType.error);
      }
    }
  }

  void _handleCompletePasswordSetup() async {
    if (!_isPasswordValid) {
      ToastNotification.show(context, message: 'Please ensure all password criteria are satisfied.', type: ToastType.error);
      return;
    }

    setState(() => _isLoading = true);

    final newPass = _newPasswordController.text;

    try {
      // 1. Update password in Supabase Auth
      final repo = ref.read(dataRepositoryProvider);
      if (repo is! MockRepository) {
        try {
          await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));
        } on AuthException catch (authErr) {
          setState(() => _isLoading = false);
          if (mounted) {
            ToastNotification.show(
              context,
              message: 'Failed to update authentication credentials: ${authErr.message}',
              type: ToastType.error,
            );
          }
          return;
        } catch (authErr) {
          debugPrint('Supabase Auth updateUser notice: $authErr');
        }
      }

      // 2. Mark account as 'active' in database
      UserModel? targetUser = _pendingUser;
      if (targetUser == null && _lastSentEmail.isNotEmpty) {
        final users = await repo.getUsers();
        final matched = users.where((u) => u.username.toLowerCase() == _lastSentEmail.toLowerCase()).toList();
        if (matched.isNotEmpty) targetUser = matched.first;
      }
      if (targetUser != null) {
        await ref.read(dataRepositoryProvider).updateUserStatus(targetUser.userId, 'active');
        ref.invalidate(employeesProvider);
        ref.invalidate(supervisorsProvider);
      }

      setState(() => _isLoading = false);

      final isActivation = _viewMode == AuthViewMode.firstTimeSetup;
      if (isActivation) {
        setState(() {
          _isLoading = false;
          _recoveryStep = RecoveryStep.enrollBiometrics;
        });
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Password created! Now optionally set up biometric quick-login for this device.',
            type: ToastType.success,
          );
        }
        return;
      }

      final successMsg = 'Password reset successfully! Please sign in with your updated credentials.';

      if (mounted) {
        ToastNotification.show(context, message: successMsg, type: ToastType.success);
      }

      // Return to login screen with email pre-filled
      setState(() {
        _viewMode = AuthViewMode.login;
        _recoveryStep = RecoveryStep.enterEmail;
        _usernameController.text = _lastSentEmail;
        _passwordController.clear();
        _otpController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _recoveryOtpController.clear();
        _showOtp = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Could not complete setup: $e', type: ToastType.error);
      }
    }
  }

  void _handleEnrollBiometrics() async {
    if (_pendingUser == null) {
      _finishActivation();
      return;
    }
    setState(() => _isEnrollingBiometric = true);

    try {
      final randomBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final challenge = base64UrlEncode(randomBytes);

      final result = await WebAuthnHelper.registerBiometric(
        challengeBase64: challenge,
        userId: _pendingUser!.userId,
        userEmail: _pendingUser!.username,
        userDisplayName: _pendingUser!.fullName,
      );

      if (!result.success) {
        setState(() => _isEnrollingBiometric = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: result.error ?? 'Biometric enrollment failed.',
            type: ToastType.warning,
          );
        }
        return;
      }

      final repo = ref.read(dataRepositoryProvider);
      final newPasskey = PasskeyModel(
        passkeyId: '',
        userId: _pendingUser!.userId,
        credentialId: result.credentialId!,
        publicKey: result.publicKey,
        deviceName: result.deviceName ?? WebAuthnHelper.getDeviceName(),
        createdAt: DateTime.now(),
      );
      await repo.addPasskey(newPasskey);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Biometric device registered! You can now use 1-click Quick Login on this device.',
          type: ToastType.success,
        );
      }

      _finishActivation();
    } catch (e) {
      setState(() => _isEnrollingBiometric = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Enrollment error: $e', type: ToastType.error);
      }
    }
  }

  void _finishActivation() {
    setState(() {
      _viewMode = AuthViewMode.login;
      _recoveryStep = RecoveryStep.enterEmail;
      _usernameController.text = _lastSentEmail;
      _passwordController.clear();
      _otpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _recoveryOtpController.clear();
      _showOtp = false;
      _isEnrollingBiometric = false;
    });
  }

  void _resetToLogin() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = 0;
      _viewMode = AuthViewMode.login;
      _recoveryStep = RecoveryStep.enterEmail;
      _showOtp = false;
      _isLoading = false;
      _isEnrollingBiometric = false;
      _recoveryEmailController.clear();
      _recoveryOtpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  // ==========================================
  // UI Builders
  // ==========================================
  Widget _buildCheckItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: isSatisfied ? AppColors.accentEmerald : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
                color: isSatisfied ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Logo
                const Center(
                  child: AppLogo(size: 72),
                ),
                const SizedBox(height: 16),
                Text(
                  _viewMode == AuthViewMode.firstTimeSetup
                      ? 'Supervisor Activation'
                      : _viewMode == AuthViewMode.forgotPassword
                          ? 'Password Recovery'
                          : 'BantayGawa Portal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _viewMode == AuthViewMode.firstTimeSetup
                      ? 'Verify your official email and establish your secure password.'
                      : _viewMode == AuthViewMode.forgotPassword
                          ? 'Recover your account credentials via secure email OTP.'
                          : 'City Environment & Natural Resources Office (ENRO)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // VIEW MODE: STANDARD LOGIN
                // ==========================================
                if (_viewMode == AuthViewMode.login) ...[
                  // Quick Biometric Sign-In Banner
                  if (_isBiometricSupported) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _handleQuickBiometricLogin,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 24,
                                  color: AppColors.accentEmerald,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quick Biometric Sign-In',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF14532D),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '1-click fingerprint, Touch ID, or Windows Hello',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Color(0xFF166534),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR SIGN IN WITH PASSWORD + OTP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  const Text(
                    'Username or Email',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                      hintText: 'Enter official username or email',
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Password',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _viewMode = AuthViewMode.forgotPassword;
                            _recoveryStep = RecoveryStep.enterEmail;
                            _recoveryEmailController.text = _usernameController.text;
                          });
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                        child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      hintText: 'Enter your password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                    ),
                  ),

                  // MFA OTP Box
                  if (_showOtp) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBlue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.accentBlue),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Multi-Factor Authentication',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter verification code dispatched to $_lastSentEmail',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onSubmitted: (_) => _handleLogin(),
                            style: const TextStyle(
                              fontSize: 19,
                              letterSpacing: 5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: AppColors.primaryNavy,
                            ),
                            maxLength: 12,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••••••',
                              hintStyle: TextStyle(
                                letterSpacing: 5,
                                color: AppColors.textMuted.withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(
                                  Icons.refresh,
                                  size: 14,
                                  color: _cooldownSeconds > 0 ? AppColors.textLight : AppColors.accentBlue,
                                ),
                                label: Text(
                                  _cooldownSeconds > 0 ? 'Resend (${_cooldownSeconds}s)' : 'Resend code',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _cooldownSeconds > 0 ? AppColors.textLight : AppColors.accentBlue,
                                  ),
                                ),
                                onPressed: _cooldownSeconds > 0 ? null : _resendOtp,
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showOtp = false;
                                    _otpController.clear();
                                  });
                                },
                                child: const Text('Change email', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  AppButton(
                    label: _showOtp ? 'Verify & Log In' : 'Log In',
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),

                  // First Time Supervisor Activation Action Link
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.accentBlue),
                      label: const Text(
                        'First-Time Supervisor? Activate Account',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentBlue),
                      ),
                      onPressed: () {
                        setState(() {
                          _viewMode = AuthViewMode.firstTimeSetup;
                          _recoveryStep = RecoveryStep.enterEmail;
                          _recoveryEmailController.text = _usernameController.text;
                        });
                      },
                    ),
                  ),
                ]

                // ==========================================
                // VIEW MODE: FIRST-TIME SETUP & FORGOT PASSWORD
                // ==========================================
                else ...[
                  // Step Indicator
                  Row(
                    children: [
                      _buildStepDot(1, 'Email', _recoveryStep == RecoveryStep.enterEmail, _recoveryStep.index > 0),
                      _buildStepLine(_recoveryStep.index >= 1),
                      _buildStepDot(2, 'Verify', _recoveryStep == RecoveryStep.verifyOtp, _recoveryStep.index > 1),
                      _buildStepLine(_recoveryStep.index >= 2),
                      _buildStepDot(3, 'Password', _recoveryStep == RecoveryStep.setPassword, _recoveryStep.index > 2),
                      if (_viewMode == AuthViewMode.firstTimeSetup) ...[
                        _buildStepLine(_recoveryStep.index >= 3),
                        _buildStepDot(4, 'Biometrics', _recoveryStep == RecoveryStep.enrollBiometrics, false),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // STEP 1: Enter Email
                  if (_recoveryStep == RecoveryStep.enterEmail) ...[
                    Text(
                      _viewMode == AuthViewMode.firstTimeSetup ? 'Official Email' : 'Email Address',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _recoveryEmailController,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _handleSendRecoveryOtp(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline, size: 18),
                        hintText: 'e.g. name@gmail.com',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _viewMode == AuthViewMode.firstTimeSetup
                          ? 'Enter the official email registered by the admin to activate your supervisor account.'
                          : 'Enter your registered email address to receive a secure one-time verification code.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Send Verification Code',
                      icon: Icons.send_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleSendRecoveryOtp,
                    ),
                  ],

                  // STEP 2: Verify OTP
                  if (_recoveryStep == RecoveryStep.verifyOtp) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_outlined, size: 18, color: AppColors.accentBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Code dispatched to $_lastSentEmail',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter Verification Code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _recoveryOtpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _handleVerifyRecoveryOtp(),
                      style: const TextStyle(
                        fontSize: 19,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppColors.primaryNavy,
                      ),
                      maxLength: 12,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••••',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please check your inbox as well as your Spam/Junk folder for the verification code.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.refresh,
                            size: 14,
                            color: _cooldownSeconds > 0 ? AppColors.textLight : AppColors.accentBlue,
                          ),
                          label: Text(
                            _cooldownSeconds > 0 ? 'Resend (${_cooldownSeconds}s)' : 'Resend code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _cooldownSeconds > 0 ? AppColors.textLight : AppColors.accentBlue,
                            ),
                          ),
                          onPressed: _cooldownSeconds > 0 ? null : _resendRecoveryOtp,
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _recoveryStep = RecoveryStep.enterEmail;
                              _recoveryOtpController.clear();
                            });
                          },
                          child: const Text('Edit email', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Verify Code & Proceed',
                      isLoading: _isLoading,
                      onPressed: _handleVerifyRecoveryOtp,
                    ),
                  ],

                  // STEP 3: Create Password with Live Strength Meter & Criteria
                  if (_recoveryStep == RecoveryStep.setPassword) ...[
                    const Text(
                      'New Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        hintText: 'Create strong password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Strength Progress Bar & Meter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Password Strength: $_strengthLabel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _newPasswordController.text.isEmpty ? AppColors.textLight : _strengthColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_strengthScore of 5 rules',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _newPasswordController.text.isEmpty ? 0 : (_strengthScore / 5.0),
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Confirm New Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_reset_outlined, size: 18),
                        hintText: 'Re-enter new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Policy Criteria Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Password Security Requirements:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryNavy),
                          ),
                          const SizedBox(height: 6),
                          _buildCheckItem('At least 8 characters long', _hasMinLength),
                          _buildCheckItem('At least 1 uppercase letter (A-Z)', _hasUppercase),
                          _buildCheckItem('At least 1 lowercase letter (a-z)', _hasLowercase),
                          _buildCheckItem('At least 1 numerical digit (0-9)', _hasDigit),
                          _buildCheckItem('At least 1 special character (!@#\$%^&*)', _hasSpecial),
                          _buildCheckItem('Passwords match exactly', _passwordsMatch),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    AppButton(
                      label: _viewMode == AuthViewMode.firstTimeSetup ? 'Activate Account & Set Password' : 'Save & Update Password',
                      icon: Icons.check_circle_outline,
                      isLoading: _isLoading,
                      onPressed: _isPasswordValid ? _handleCompletePasswordSetup : null,
                    ),
                  ],

                  // STEP 4: Optional Biometric Registration (Supervisor Activation)
                  if (_recoveryStep == RecoveryStep.enrollBiometrics) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fingerprint_rounded, size: 48, color: AppColors.accentEmerald),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Register Biometric Quick-Login',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14532D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isBiometricSupported
                                ? 'Hardware biometric sensor detected on this device (Windows Hello / Touch ID / Fingerprint). Register now to sign in instantly with a single touch without typing your password.'
                                : 'No platform biometric sensor detected on this computer. You can proceed with standard Password + Email OTP Multi-Factor Authentication.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isBiometricSupported) ...[
                      AppButton(
                        label: 'Register Fingerprint / Touch ID',
                        icon: Icons.fingerprint,
                        isLoading: _isEnrollingBiometric,
                        onPressed: _handleEnrollBiometrics,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Skip and Go to Sign In',
                        variant: ButtonVariant.outline,
                        onPressed: _finishActivation,
                      ),
                    ] else ...[
                      AppButton(
                        label: 'Complete Activation & Sign In',
                        icon: Icons.check_circle_outline,
                        onPressed: _finishActivation,
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 14),
                      label: const Text('Back to Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: _resetToLogin,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int step, String label, bool isActive, bool isCompleted) {
    final color = isCompleted
        ? AppColors.accentEmerald
        : isActive
            ? AppColors.accentBlue
            : AppColors.textLight;

    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.accentEmerald : (isActive ? AppColors.accentBlue : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : AppColors.textLight,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: isCompleted ? AppColors.accentEmerald : const Color(0xFFE2E8F0),
      ),
    );
  }
}


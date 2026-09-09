import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _usernameController = TextEditingController(text: 'admin_enro');
  final _passwordController = TextEditingController(text: '••••••••');
  final _otpController = TextEditingController();
  bool _showOtp = false;
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _isLoading = false);

    if (!_showOtp) {
      setState(() => _showOtp = true);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'MFA Code sent. Use OTP: 123456 (or demo quick-login below).',
          type: ToastType.info,
        );
      }
      return;
    }

    // Finish Login
    ref.read(currentUserProvider.notifier).state = UserModel(
      userId: 'user-admin-1',
      username: 'admin_enro',
      firstName: 'Roberto',
      lastName: 'Del Rosario',
      contactNumber: '+63 917 111 0001',
      role: UserRole.admin,
      status: 'active',
    );
    ref.read(activeNavProvider.notifier).state = 'dashboard';
    if (mounted) {
      ToastNotification.show(context, message: 'Welcome back, Admin Roberto!', type: ToastType.success);
    }
  }

  void _demoLoginAs(UserRole role) {
    if (role == UserRole.admin) {
      ref.read(currentUserProvider.notifier).state = UserModel(
        userId: 'user-admin-1',
        username: 'admin_enro',
        firstName: 'Roberto',
        lastName: 'Del Rosario',
        contactNumber: '+63 917 111 0001',
        role: UserRole.admin,
        status: 'active',
      );
      ToastNotification.show(context, message: 'Signed in as Administrator', type: ToastType.success);
    } else {
      ref.read(currentUserProvider.notifier).state = UserModel(
        userId: 'user-sup-1',
        username: 'sup_juan',
        firstName: 'Juan',
        lastName: 'Santos',
        contactNumber: '+63 917 222 0002',
        role: UserRole.supervisor,
        status: 'active',
        assignedAreaId: 'area-1',
        assignedAreaName: 'Ormoc City Hall Zone',
      );
      ToastNotification.show(context, message: 'Signed in as Field Supervisor (Juan Santos)', type: ToastType.success);
    }
    ref.read(activeNavProvider.notifier).state = 'dashboard';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
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
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 6),
                const Text(
                  'Intelligent Workforce Verification System\nEnvironment and Natural Resources Office (ENRO)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Username
                const Text(
                  'Username or Email',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                    hintText: 'Enter username',
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                const Text(
                  'Password',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline, size: 18),
                    hintText: 'Enter password',
                  ),
                ),

                if (_showOtp) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Multi-Factor Authentication (MFA OTP)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.security, size: 18),
                      hintText: 'Enter 6-digit OTP (e.g. 123456)',
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                AppButton(
                  label: _showOtp ? 'Verify OTP & Enter' : 'Sign In with MFA',
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),

                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('DEMO QUICK-ACCESS', style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick Demo Login Buttons
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
            ),
          ),
        ),
      ),
    );
  }
}

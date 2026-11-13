import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_dashboard/features/auth/login_view.dart';
import 'package:web_dashboard/data/models/user_model.dart';
import 'package:web_dashboard/data/repositories/mock_repository.dart';
import 'package:web_dashboard/data/repositories/repository_provider.dart';

void main() {
  testWidgets('LoginView renders standard login, toggles to First-Time Activation, and validates Password Strength', (tester) async {
    final mockRepo = MockRepository(
      initialUsers: [
        UserModel(
          userId: 'user-admin',
          username: 'admin@ormoc.gov.ph',
          firstName: 'Mark Kevin',
          lastName: 'Canonoy',
          contactNumber: '+63 917 555 0199',
          role: UserRole.admin,
          status: 'active',
          schedule: 'Mon-Fri 08:00 - 17:00',
        ),
        UserModel(
          userId: 'user-sup-pending',
          username: 'sup_pending@ormoc.gov.ph',
          firstName: 'Juan',
          lastName: 'Santos',
          contactNumber: '+63 917 222 0002',
          role: UserRole.supervisor,
          status: 'pending',
          schedule: 'Mon-Fri 08:00 - 17:00',
        ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: LoginView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial State: Standard Login Mode
    expect(find.text('BantayGawa Portal'), findsOneWidget);
    expect(find.text('Username or Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('First-Time Supervisor? Activate Account'), findsOneWidget);

    // 2. Switch to First-Time Supervisor Activation
    await tester.tap(find.text('First-Time Supervisor? Activate Account'));
    await tester.pumpAndSettle();

    expect(find.text('Supervisor Activation'), findsOneWidget);
    expect(find.text('Official Email'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);

    // 3. Enter Pending Supervisor Email & Send Verification
    await tester.enterText(find.byType(TextField).first, 'sup_pending@ormoc.gov.ph');
    await tester.tap(find.text('Send Verification Code'));
    await tester.pumpAndSettle();

    // Step 2: Verification Code screen
    expect(find.text('Enter Verification Code'), findsOneWidget);

    // Enter test verification code
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Verify Code & Proceed'));
    await tester.pumpAndSettle();

    // Step 3: Password Creation & Strength Meter
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
    expect(find.text('Password Security Requirements:'), findsOneWidget);
    expect(find.text('At least 8 characters long'), findsOneWidget);

    // Test password strength validation
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'weak');
    await tester.pumpAndSettle();
    expect(find.text('Password Strength: Weak'), findsOneWidget);

    // Enter strong password meeting all criteria
    await tester.enterText(textFields.at(0), 'OrmocENRO@2026!');
    await tester.enterText(textFields.at(1), 'OrmocENRO@2026!');
    await tester.pumpAndSettle();

    expect(find.text('Password Strength: Strong'), findsOneWidget);
    expect(find.text('Activate Account & Set Password'), findsOneWidget);

    // Submit activation
    await tester.tap(find.text('Activate Account & Set Password'));
    await tester.pumpAndSettle();

    // Step 4: Register Biometric Quick-Login
    expect(find.text('Register Biometric Quick-Login'), findsOneWidget);
    final finishBtn = find.text('Complete Activation & Sign In').evaluate().isNotEmpty
        ? find.text('Complete Activation & Sign In')
        : find.text('Skip and Go to Sign In');
    await tester.tap(finishBtn);
    await tester.pumpAndSettle();

    // Successfully transitioned back to login with email prefilled
    expect(find.text('BantayGawa Portal'), findsOneWidget);
    expect(find.text('sup_pending@ormoc.gov.ph'), findsOneWidget);

    // User status in repository should now be active
    final updatedUsers = await mockRepo.getUsers();
    final activatedUser = updatedUsers.firstWhere((u) => u.userId == 'user-sup-pending');
    expect(activatedUser.status, 'active');
  });

  testWidgets('LoginView Forgot Password flow guides user to password recovery and updates credentials', (tester) async {
    final mockRepo = MockRepository(
      initialUsers: [
        UserModel(
          userId: 'user-admin',
          username: 'admin@ormoc.gov.ph',
          firstName: 'Mark Kevin',
          lastName: 'Canonoy',
          contactNumber: '+63 917 555 0199',
          role: UserRole.admin,
          status: 'active',
          schedule: 'Mon-Fri 08:00 - 17:00',
        ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: LoginView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Forgot Password
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Password Recovery'), findsOneWidget);

    // Enter email
    await tester.enterText(find.byType(TextField).first, 'admin@ormoc.gov.ph');
    await tester.tap(find.text('Send Verification Code'));
    await tester.pumpAndSettle();

    // Verify OTP (accepts 8-digit OTP as returned by Supabase)
    expect(find.text('Enter Verification Code'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '12345678');
    await tester.tap(find.text('Verify Code & Proceed'));
    await tester.pumpAndSettle();

    // Set new password
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'NewSecure@2026#');
    await tester.enterText(textFields.at(1), 'NewSecure@2026#');
    await tester.pumpAndSettle();

    expect(find.text('Password Strength: Strong'), findsOneWidget);
    expect(find.text('Save & Update Password'), findsOneWidget);

    await tester.tap(find.text('Save & Update Password'));
    await tester.pumpAndSettle();

    // Returned to login view
    expect(find.text('BantayGawa Portal'), findsOneWidget);
  });

  testWidgets('LoginView enforces password authentication and blocks login with wrong password', (tester) async {
    final mockRepo = MockRepository(
      initialUsers: [
        UserModel(
          userId: 'user-admin',
          username: 'admin@ormoc.gov.ph',
          firstName: 'Mark Kevin',
          lastName: 'Canonoy',
          contactNumber: '+63 917 555 0199',
          role: UserRole.admin,
          status: 'active',
          schedule: 'Mon-Fri 08:00 - 17:00',
        ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: LoginView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter valid email but intentionally wrong password
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'admin@ormoc.gov.ph');
    await tester.enterText(textFields.at(1), 'wrong_password');

    // Tap Log In
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    // Verify error toast was shown and did NOT advance to OTP
    expect(find.textContaining('Incorrect password'), findsOneWidget);
    expect(find.text('Enter Verification Code'), findsNothing);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('LoginView allows demo account markkevincanonoy99@gmail.com to bypass via AuthConfig', (tester) async {
    final mockRepo = MockRepository(
      initialUsers: [
        UserModel(
          userId: 'user-demo-admin',
          username: 'markkevincanonoy99@gmail.com',
          firstName: 'Mark Kevin',
          lastName: 'Canonoy',
          contactNumber: '+63 917 555 0199',
          role: UserRole.admin,
          status: 'active',
          schedule: 'Mon-Fri 08:00 - 17:00',
        ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: LoginView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter demo account
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'markkevincanonoy99@gmail.com');
    await tester.enterText(textFields.at(1), 'any_password');

    // Tap Log In
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    // Verify demo bypass message is displayed and OTP is skipped
    expect(find.textContaining('Demo Mode - OTP bypassed'), findsOneWidget);
  });

  testWidgets('LoginView OTP input validates 6-8 digit length and handles Resend code button', (tester) async {
    final mockRepo = MockRepository(
      initialUsers: [
        UserModel(
          userId: 'user-admin',
          username: 'admin@ormoc.gov.ph',
          firstName: 'Mark Kevin',
          lastName: 'Canonoy',
          contactNumber: '+63 917 555 0199',
          role: UserRole.admin,
          status: 'active',
          schedule: 'Mon-Fri 08:00 - 17:00',
        ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: LoginView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Switch to Forgot Password
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'admin@ormoc.gov.ph');
    await tester.tap(find.text('Send Verification Code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Verification Code'), findsOneWidget);

    // 2. Test short OTP (< 6 digits) shows clean "Enter verification code." error
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.tap(find.text('Verify Code & Proceed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter verification code.'), findsOneWidget);

    // 3. Test Resend code button starts cooldown
    // Notice cooldown was already started by sending initial verification code (60s)
    expect(find.textContaining('Resend'), findsOneWidget);

    // 4. Test entering valid 8-digit OTP (e.g. 12345678) proceeds to password setup
    await tester.enterText(find.byType(TextField).first, '12345678');
    await tester.tap(find.text('Verify Code & Proceed'));
    await tester.pumpAndSettle();

    expect(find.text('New Password'), findsOneWidget);
  });
}

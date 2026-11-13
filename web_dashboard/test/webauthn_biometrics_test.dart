import 'package:flutter_test/flutter_test.dart';
import 'package:web_dashboard/data/models/passkey_model.dart';
import 'package:web_dashboard/data/models/user_model.dart';
import 'package:web_dashboard/data/repositories/mock_repository.dart';

void main() {
  group('WebAuthn / Passkey Biometrics Repository Tests', () {
    late MockRepository repo;
    final testUser = UserModel(
      userId: 'test-user-sup',
      username: 'supervisor@ormoc.gov.ph',
      firstName: 'Maria',
      lastName: 'Santos',
      contactNumber: '+63 918 000 1111',
      role: UserRole.supervisor,
      status: 'active',
      schedule: 'Unassigned',
    );

    setUp(() {
      repo = MockRepository(initialUsers: [testUser]);
    });

    test('addPasskey stores credential and getUserPasskeys returns user devices', () async {
      final passkey = PasskeyModel(
        passkeyId: 'passkey-1',
        userId: testUser.userId,
        credentialId: 'cred-abc-123',
        publicKey: 'pubkey-sample-bytes',
        deviceName: 'Windows Hello (Chrome)',
        createdAt: DateTime.now(),
      );

      await repo.addPasskey(passkey);

      final userPasskeys = await repo.getUserPasskeys(testUser.userId);
      expect(userPasskeys.length, 1);
      expect(userPasskeys.first.credentialId, 'cred-abc-123');
      expect(userPasskeys.first.deviceName, 'Windows Hello (Chrome)');
    });

    test('findUserByPasskeyCredential resolves correct UserModel', () async {
      final passkey = PasskeyModel(
        passkeyId: 'passkey-2',
        userId: testUser.userId,
        credentialId: 'cred-touchid-456',
        publicKey: 'pubkey-apple-bytes',
        deviceName: 'Mac Touch ID (Safari)',
        createdAt: DateTime.now(),
      );

      await repo.addPasskey(passkey);

      final matchedUser = await repo.findUserByPasskeyCredential('cred-touchid-456');
      expect(matchedUser, isNotNull);
      expect(matchedUser!.userId, testUser.userId);
      expect(matchedUser.username, 'supervisor@ormoc.gov.ph');
    });

    test('deletePasskey removes revoked device', () async {
      final passkey = PasskeyModel(
        passkeyId: 'passkey-3',
        userId: testUser.userId,
        credentialId: 'cred-xyz-789',
        deviceName: 'Android Biometric',
        createdAt: DateTime.now(),
      );

      await repo.addPasskey(passkey);
      var passkeys = await repo.getUserPasskeys(testUser.userId);
      expect(passkeys.length, 1);

      await repo.deletePasskey('passkey-3');
      passkeys = await repo.getUserPasskeys(testUser.userId);
      expect(passkeys.isEmpty, true);
    });
  });
}

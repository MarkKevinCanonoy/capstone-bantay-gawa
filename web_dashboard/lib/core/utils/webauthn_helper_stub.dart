import 'package:flutter/foundation.dart';

class WebAuthnRegistrationResult {
  final bool success;
  final String? credentialId;
  final String? publicKey;
  final String? deviceName;
  final String? error;

  const WebAuthnRegistrationResult({
    required this.success,
    this.credentialId,
    this.publicKey,
    this.deviceName,
    this.error,
  });
}

class WebAuthnAuthenticationResult {
  final bool success;
  final String? credentialId;
  final String? error;

  const WebAuthnAuthenticationResult({
    required this.success,
    this.credentialId,
    this.error,
  });
}

class WebAuthnHelper {
  static Future<bool> isPlatformBiometricAvailable() async {
    debugPrint('WebAuthn platform check stubbed for non-web runtime.');
    return false;
  }

  static Future<WebAuthnRegistrationResult> registerBiometric({
    required String challengeBase64,
    required String userId,
    required String userEmail,
    required String userDisplayName,
  }) async {
    return const WebAuthnRegistrationResult(
      success: false,
      error: 'WebAuthn is only available on web browsers.',
    );
  }

  static Future<WebAuthnAuthenticationResult> authenticateBiometric({
    required String challengeBase64,
    List<String>? allowedCredentialIds,
  }) async {
    return const WebAuthnAuthenticationResult(
      success: false,
      error: 'WebAuthn is only available on web browsers.',
    );
  }

  static String getDeviceName() => 'Non-Web Device';
}

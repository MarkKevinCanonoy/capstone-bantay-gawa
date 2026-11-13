import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('bantayGawaWebAuthn.isPlatformBiometricAvailable')
external JSPromise<JSBoolean> _jsIsPlatformBiometricAvailable();

@JS('bantayGawaWebAuthn.registerPlatformBiometric')
external JSPromise<JSString> _jsRegisterPlatformBiometric(
  JSString challenge,
  JSString userId,
  JSString userEmail,
  JSString userDisplayName,
);

@JS('bantayGawaWebAuthn.authenticatePlatformBiometric')
external JSPromise<JSString> _jsAuthenticatePlatformBiometric(
  JSString challenge,
  JSArray<JSString>? allowedCredentialIds,
);

@JS('bantayGawaWebAuthn.getDeviceName')
external JSString _jsGetDeviceName();

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
  /// Checks if the client device possesses a platform biometric sensor (Windows Hello, Touch ID, Face ID, Android Biometric)
  static Future<bool> isPlatformBiometricAvailable() async {
    try {
      final jsBool = await _jsIsPlatformBiometricAvailable().toDart;
      return jsBool.toDart;
    } catch (e) {
      debugPrint('[WebAuthnHelper] Error checking platform biometric availability: $e');
      return false;
    }
  }

  /// Registers a new WebAuthn credential (Passkey) using the platform biometric authenticator
  static Future<WebAuthnRegistrationResult> registerBiometric({
    required String challengeBase64,
    required String userId,
    required String userEmail,
    required String userDisplayName,
  }) async {
    try {
      final jsResult = await _jsRegisterPlatformBiometric(
        challengeBase64.toJS,
        userId.toJS,
        userEmail.toJS,
        userDisplayName.toJS,
      ).toDart;

      final rawString = jsResult.toDart;
      final Map<String, dynamic> data = jsonDecode(rawString);

      if (data['success'] == true) {
        return WebAuthnRegistrationResult(
          success: true,
          credentialId: data['credentialId'] as String?,
          publicKey: data['publicKey'] as String?,
          deviceName: data['deviceName'] as String? ?? getDeviceName(),
        );
      } else {
        return WebAuthnRegistrationResult(
          success: false,
          error: data['error'] as String? ?? 'Biometric setup failed.',
        );
      }
    } catch (e) {
      debugPrint('[WebAuthnHelper] Registration error: $e');
      return WebAuthnRegistrationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Prompts the user's platform biometric authenticator for Quick 1-Click login
  static Future<WebAuthnAuthenticationResult> authenticateBiometric({
    required String challengeBase64,
    List<String>? allowedCredentialIds,
  }) async {
    try {
      JSArray<JSString>? jsList;
      if (allowedCredentialIds != null && allowedCredentialIds.isNotEmpty) {
        jsList = allowedCredentialIds.map((s) => s.toJS).toList().toJS;
      }

      final jsResult = await _jsAuthenticatePlatformBiometric(
        challengeBase64.toJS,
        jsList,
      ).toDart;

      final rawString = jsResult.toDart;
      final Map<String, dynamic> data = jsonDecode(rawString);

      if (data['success'] == true) {
        return WebAuthnAuthenticationResult(
          success: true,
          credentialId: data['credentialId'] as String?,
        );
      } else {
        return WebAuthnAuthenticationResult(
          success: false,
          error: data['error'] as String? ?? 'Biometric verification failed.',
        );
      }
    } catch (e) {
      debugPrint('[WebAuthnHelper] Authentication error: $e');
      return WebAuthnAuthenticationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  static String getDeviceName() {
    try {
      return _jsGetDeviceName().toDart;
    } catch (_) {
      return 'Web Biometric';
    }
  }
}

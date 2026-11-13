// BantayGawa WebAuthn / Passkeys Bridge for Biometric Verification (FIDO2 / Platform Authenticator)
// Supports Windows Hello, Touch ID, Apple Face ID, and Android Biometrics in modern web browsers.

(function () {
  function bufferToBase64(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
  }

  function base64ToBuffer(base64) {
    if (!base64) return new ArrayBuffer(0);
    let str = base64.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) {
      str += '=';
    }
    const binary = window.atob(str);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  function getDeviceName() {
    const ua = navigator.userAgent;
    let os = 'Device';
    if (/Windows/i.test(ua)) os = 'Windows Hello';
    else if (/Macintosh|Mac OS X/i.test(ua)) os = 'Mac Touch ID';
    else if (/Android/i.test(ua)) os = 'Android Biometric';
    else if (/iPhone|iPad/i.test(ua)) os = 'Apple Face/Touch ID';
    else if (/Linux/i.test(ua)) os = 'Linux Security Key';

    let browser = 'Browser';
    if (/Edg\//i.test(ua)) browser = 'Edge';
    else if (/Chrome\//i.test(ua)) browser = 'Chrome';
    else if (/Safari\//i.test(ua) && !/Chrome/i.test(ua)) browser = 'Safari';
    else if (/Firefox\//i.test(ua)) browser = 'Firefox';

    return `${os} (${browser})`;
  }

  async function isPlatformBiometricAvailable() {
    try {
      if (!window.PublicKeyCredential) return false;
      if (
        !window.isSecureContext &&
        window.location.hostname !== 'localhost' &&
        window.location.hostname !== '127.0.0.1'
      ) {
        return false;
      }
      if (typeof PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable !== 'function') {
        return false;
      }
      return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    } catch (e) {
      console.warn('[BantayGawa WebAuthn] Availability check failed:', e);
      return false;
    }
  }

  async function registerPlatformBiometric(challengeBase64, userId, userEmail, userDisplayName) {
    try {
      if (!window.PublicKeyCredential) {
        return JSON.stringify({
          success: false,
          error: 'Biometric authentication (WebAuthn) is not supported in this browser.',
        });
      }

      const challengeBuffer = base64ToBuffer(challengeBase64);
      const userBuffer = new TextEncoder().encode(userId);
      const rpId = window.location.hostname;

      const createOptions = {
        publicKey: {
          challenge: challengeBuffer,
          rp: {
            name: 'BantayGawa ENRO Ormoc',
            id: rpId,
          },
          user: {
            id: userBuffer,
            name: userEmail,
            displayName: userDisplayName || userEmail,
          },
          pubKeyCredParams: [
            { alg: -7, type: 'public-key' }, // ES256
            { alg: -257, type: 'public-key' }, // RS256
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            userVerification: 'required',
            residentKey: 'preferred',
          },
          timeout: 60000,
          attestation: 'none',
        },
      };

      const credential = await navigator.credentials.create(createOptions);
      if (!credential) {
        return JSON.stringify({ success: false, error: 'Registration cancelled.' });
      }

      const credIdBase64 = bufferToBase64(credential.rawId);
      let pubKeyBase64 = '';
      if (credential.response && typeof credential.response.getPublicKey === 'function') {
        const pk = credential.response.getPublicKey();
        if (pk) pubKeyBase64 = bufferToBase64(pk);
      }

      return JSON.stringify({
        success: true,
        credentialId: credIdBase64,
        publicKey: pubKeyBase64,
        deviceName: getDeviceName(),
      });
    } catch (err) {
      console.error('[BantayGawa WebAuthn] Registration error:', err);
      const isCancelled =
        err.name === 'NotAllowedError' || err.name === 'AbortError';
      return JSON.stringify({
        success: false,
        error: isCancelled
          ? 'Biometric setup was cancelled or timed out.'
          : (err.message || 'Unknown biometric error'),
      });
    }
  }

  async function authenticatePlatformBiometric(challengeBase64, allowedCredentialIds) {
    try {
      if (!window.PublicKeyCredential) {
        return JSON.stringify({
          success: false,
          error: 'Biometric authentication (WebAuthn) is not supported in this browser.',
        });
      }

      const challengeBuffer = base64ToBuffer(challengeBase64);
      const getOptions = {
        publicKey: {
          challenge: challengeBuffer,
          userVerification: 'required',
          timeout: 60000,
        },
      };

      if (Array.isArray(allowedCredentialIds) && allowedCredentialIds.length > 0) {
        getOptions.publicKey.allowCredentials = allowedCredentialIds.map(function (id) {
          return {
            id: base64ToBuffer(id),
            type: 'public-key',
          };
        });
      }

      const assertion = await navigator.credentials.get(getOptions);
      if (!assertion) {
        return JSON.stringify({ success: false, error: 'Verification cancelled.' });
      }

      const credIdBase64 = bufferToBase64(assertion.rawId);
      return JSON.stringify({
        success: true,
        credentialId: credIdBase64,
      });
    } catch (err) {
      console.error('[BantayGawa WebAuthn] Authentication error:', err);
      const isCancelled =
        err.name === 'NotAllowedError' || err.name === 'AbortError';
      return JSON.stringify({
        success: false,
        error: isCancelled
          ? 'Biometric scan was cancelled or timed out.'
          : (err.message || 'Verification failed'),
      });
    }
  }

  window.bantayGawaWebAuthn = {
    isPlatformBiometricAvailable: isPlatformBiometricAvailable,
    registerPlatformBiometric: registerPlatformBiometric,
    authenticatePlatformBiometric: authenticatePlatformBiometric,
    getDeviceName: getDeviceName,
  };
})();

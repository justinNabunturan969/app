import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Uses the operating system's biometric prompt. No fingerprint data or
/// account password is ever exposed to, or stored by, the application.
class BiometricAuthenticator {
  BiometricAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  /// Returns null when authentication succeeds; otherwise, a safe message
  /// suitable for showing in the sign-in UI.
  Future<String?> authenticate() async {
    if (kIsWeb) {
      return 'Fingerprint sign-in is available in the installed mobile app.';
    }

    try {
      final supported = await _localAuthentication.isDeviceSupported();
      final canCheck = await _localAuthentication.canCheckBiometrics;
      if (!supported || !canCheck) {
        return 'This device does not support biometric sign-in.';
      }

      final biometrics = await _localAuthentication.getAvailableBiometrics();
      if (biometrics.isEmpty) {
        return 'Set up a fingerprint or other device biometric first.';
      }

      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Confirm your identity to sign in to PUP-ITech.',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      return authenticated ? null : 'Fingerprint sign-in was cancelled.';
    } catch (_) {
      return 'Fingerprint sign-in is unavailable. Check your device settings.';
    }
  }
}

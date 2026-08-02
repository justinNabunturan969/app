import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
// nfc_manager 4.x splits the UID-extraction API per platform. We import both
// the Android and iOS tag packages so the service can normalise the card UID
// into a stable hex string on either device.
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

/// Centralised NFC read/write entry point.
///
/// Wraps the plugin's polling session, normalises the card UID into a
/// stable hex string (the same card always reads back to the same string
/// across sessions and devices), and exposes the tap as a broadcast
/// stream so any screen can subscribe.
///
/// ## Lifecycle
/// - `isAvailable()` — call before opening the scanner to give the user
///   a clean error if the device has no NFC or the user disabled it.
/// - `startSession(prompt: ...)` — begins polling. The session auto-closes
///   on the first successful read so the staff don't have to tap "done".
/// - `stopSession()` — call when the user backs out, or the screen
///   disposes.
class NfcService {
  NfcService._();
  static final NfcService instance = NfcService._();

  final StreamController<NfcTap> _tapController =
      StreamController<NfcTap>.broadcast();
  Stream<NfcTap> get onTap => _tapController.stream;

  bool _sessionActive = false;
  bool get isSessionActive => _sessionActive;

  /// True if the device has an NFC radio and the user has it enabled.
  Future<bool> isAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (e) {
      debugPrint('NfcService.isAvailable error: $e');
      return false;
    }
  }

  /// Begin polling for an NFC tag. Throws [NfcException] on hard failure
  /// (no hardware, OS-level permission denied). First successful read
  /// emits on [onTap] and the session closes itself.
  Future<void> startSession({
    String? alertMessage,
    String? prompt,
  }) async {
    if (_sessionActive) return;

    final available = await isAvailable();
    if (!available) {
      throw const NfcException(
        'NFC is not available on this device, or it is turned off. '
        'Enable it in Settings, then try again.',
      );
    }

    // The native dialog only renders on iOS — the Android system handles
    // its own tap-to-card UI, so the prompt is intentionally iOS-only.
    final iosMessage = alertMessage ??
        (prompt != null ? '$prompt — hold your card near the phone.' : null);

    _sessionActive = true;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: iosMessage,
        onDiscovered: (NfcTag tag) async {
          try {
            final uid = _readUid(tag);
            if (uid == null || uid.isEmpty) {
              throw const NfcException(
                'Could not read the card UID. The card may be damaged or '
                'using an unsupported format.',
              );
            }
            _tapController.add(
              NfcTap(
                uidHex: bytesToHex(uid),
                uidBytes: uid,
                readAt: DateTime.now(),
                techList: _readTechList(tag),
              ),
            );
          } catch (e, st) {
            _tapController.addError(e, st);
          } finally {
            await stopSession();
          }
        },
      );
    } catch (e) {
      _sessionActive = false;
      if (e is NfcException) rethrow;
      throw NfcException('Failed to start NFC session: $e');
    }
  }

  Future<void> stopSession({
    String? alertMessage,
    String? errorMessage,
  }) async {
    if (!_sessionActive) return;
    _sessionActive = false;
    try {
      // Only iOS consumes these — the underlying API silently drops the
      // values on Android, but we still pass them through so callers can
      // keep using a single cross-platform entry point.
      await NfcManager.instance.stopSession(
        alertMessageIos: alertMessage,
        errorMessageIos: errorMessage,
      );
    } catch (_) {
      // The session may already be closed if the user moved the phone away.
    }
  }

  /// Pulls the card UID from the platform-specific tag data. Student ID
  /// cards in PUP-ITech are ISO 14443 (MIFARE Classic / Ultralight / NTAG)
  /// on Android, and may also be MIFARE / ISO 15693 on iOS.
  Uint8List? _readUid(NfcTag tag) {
    // Android: every discovered tag exposes its UID through NfcTagAndroid.
    final android = NfcTagAndroid.from(tag);
    if (android != null && android.id.isNotEmpty) {
      return android.id;
    }
    // iOS: MIFARE and ISO 15693 are the common student card formats.
    final mifare = MiFareIos.from(tag);
    if (mifare != null && mifare.identifier.isNotEmpty) {
      return mifare.identifier;
    }
    final iso15693 = Iso15693Ios.from(tag);
    if (iso15693 != null && iso15693.identifier.isNotEmpty) {
      return iso15693.identifier;
    }
    return null;
  }

  /// Returns the list of NFC technologies the card advertised, e.g.
  /// `["android.nfc.tech.NfcA", "android.nfc.tech.MifareClassic"]`.
  /// Useful for debugging "this card didn't read on iPhone" issues.
  List<String> _readTechList(NfcTag tag) {
    final android = NfcTagAndroid.from(tag);
    if (android != null) return android.techList;
    return const <String>[];
  }

  /// Public so widgets can show the user the raw ID (e.g. for support).
  static String bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  void dispose() {
    stopSession();
    _tapController.close();
  }
}

/// One successful read of an NFC card.
class NfcTap {
  NfcTap({
    required this.uidHex,
    required this.uidBytes,
    required this.readAt,
    required this.techList,
  });

  /// Colon-separated hex, e.g. `04:A3:B2:7F:1C:90:80`. This is the
  /// stable identifier you compare against the student whitelist.
  final String uidHex;

  /// Raw UID bytes for hashing / signed payloads.
  final Uint8List uidBytes;

  /// Wall-clock time the tap was observed.
  final DateTime readAt;

  /// NFC technologies the card advertised (nfca, nfcb, iso15693, ...).
  /// Useful for debugging "this card didn't read on iPhone" issues.
  final List<String> techList;

  /// Convenience: compact form without colons, e.g. `04A3B27F1C9080`.
  String get uidCompact => uidHex.replaceAll(':', '');

  @override
  String toString() => 'NfcTap($uidHex @ $readAt)';
}

class NfcException implements Exception {
  const NfcException(this.message);
  final String message;
  @override
  String toString() => message;
}

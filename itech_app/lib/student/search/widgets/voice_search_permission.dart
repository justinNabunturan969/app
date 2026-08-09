import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as st;

import 'voice_search_permission_stub.dart'
    if (dart.library.js_interop) 'voice_search_permission_web.dart';

/// What happened when we asked the browser / OS for microphone access.
///
/// The overlay turns each non-[granted] state into a tailored message
/// with the next step the user can take (unmute the tab, allow in
/// browser settings, plug in a mic, etc.). The same enum is used on
/// every platform so the UI doesn't have to branch.
enum MicrophonePermissionStatus {
  /// The user (or the OS) granted microphone access. The recognizer
  /// can start.
  granted,

  /// The user explicitly denied microphone access, or the OS is
  /// blocking us. The UI should explain how to re-enable.
  denied,

  /// The page is served over an insecure origin (HTTP, not HTTPS)
  /// and the browser won't expose `getUserMedia`. The UI should
  /// point the user to the secure URL.
  insecure,

  /// The device has no microphone, or the browser doesn't support
  /// the Media Devices API. The UI should suggest text search.
  noMicrophone,

  /// Something else went wrong (the plugin failed to initialize,
  /// the recognizer is missing, etc.). The UI should fall back to
  /// text search.
  unsupported,
}

/// Cross-platform microphone-permission helper.
///
/// On web we route through a `window.__pupRequestMic` helper defined
/// in `web/index.html` that calls `navigator.mediaDevices.getUserMedia`.
/// That path is the most reliable way to surface a microphone prompt
/// on mobile browsers — the Web Speech API's own prompt is easy to
/// miss on a phone and there is no clean "how do I undo my denial"
/// affordance. Once `getUserMedia` has been granted, the
/// `speech_to_text` plugin (which internally uses
/// `webkitSpeechRecognition` / `SpeechRecognition`) works against the
/// same permission grant.
///
/// On native (Android / iOS) the OS-level permission dialog is raised
/// by `speech_to_text.initialize()`. We don't add a second prompt
/// layer — the platform dialog is already the source of truth.
class MicrophonePermission {
  const MicrophonePermission._();

  /// Ask the user for microphone access. Safe to call repeatedly; the
  /// browser / OS will not re-prompt if a decision is already
  /// remembered.
  static Future<MicrophonePermissionStatus> request() async {
    if (kIsWeb) {
      return _requestWeb();
    }
    return _requestNative();
  }

  // ── Web ─────────────────────────────────────────────────────────────

  static Future<MicrophonePermissionStatus> _requestWeb() async {
    final reason = await webRequestMic();
    switch (reason) {
      case 'granted':
        return MicrophonePermissionStatus.granted;
      case 'denied':
        return MicrophonePermissionStatus.denied;
      case 'insecure':
        return MicrophonePermissionStatus.insecure;
      case 'no_microphone':
        return MicrophonePermissionStatus.noMicrophone;
      default:
        return MicrophonePermissionStatus.unsupported;
    }
  }

  // ── Native ──────────────────────────────────────────────────────────

  static Future<MicrophonePermissionStatus> _requestNative() async {
    final speech = st.SpeechToText();
    final available = await speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    if (available) return MicrophonePermissionStatus.granted;

    // `initialize` returns false both for "permission denied" and for
    // "no recognizer installed". We don't have a clean way to
    // distinguish them from the public API, so collapse them into the
    // generic "unsupported" state — the overlay's recovery path is
    // "try again" either way.
    return MicrophonePermissionStatus.unsupported;
  }
}

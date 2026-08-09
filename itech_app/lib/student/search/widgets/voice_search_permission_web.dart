library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// Web-only implementation of the microphone permission request.
///
/// This file is imported only when `dart.library.js_interop` is available
/// (i.e. the web target). It routes microphone access through a
/// `window.__pupRequestMic` helper defined in `web/index.html` that calls
/// `navigator.mediaDevices.getUserMedia`. On native targets the conditional
/// import stub (`voice_search_permission_stub.dart`) supplies this as a no-op
/// and the main file uses the `speech_to_text` plugin path instead.

/// Requests microphone access on the web and returns a machine-readable
/// outcome string. The browser / OS will not re-prompt if a decision is
/// already remembered.
///
/// Returns one of: `'granted'`, `'denied'`, `'insecure'`,
/// `'no_microphone'`, or `'unsupported'`.
Future<String> webRequestMic() async {
  try {
    final result = await _jsRequestMic().toDart;
    // `dart:js_interop_unsafe` exposes JS object properties through
    // the `[]` operator on `JSObject` (the older `getProperty` accessor
    // was removed). We pull `granted` and `reason` out of the shape
    // produced by the `__pupRequestMic` bridge in `web/index.html`.
    final grantedRaw = result['granted'];
    if (grantedRaw.isA<JSBoolean>()) {
      final granted = (grantedRaw as JSBoolean).toDart;
      if (granted) return 'granted';
    }
    final reason = _readReason(result);
    switch (reason) {
      case 'denied':
        return 'denied';
      case 'insecure':
        return 'insecure';
      case 'no_microphone':
        return 'no_microphone';
      default:
        return 'unsupported';
    }
  } on Object catch (e) {
    debugPrint('MicrophonePermission: JS bridge failed: $e');
    return 'unsupported';
  }
}

String _readReason(JSObject result) {
  final raw = result['reason'];
  if (raw.isA<JSString>()) {
    return (raw as JSString).toDart;
  }
  return '';
}

// ── JS bridge ────────────────────────────────────────────────────────
// `window.__pupRequestMic` is registered by the inline script at the
// bottom of `web/index.html`. It returns a Promise<{granted, reason}>.
@JS('window.__pupRequestMic')
external JSPromise<JSObject> _jsRequestMic();

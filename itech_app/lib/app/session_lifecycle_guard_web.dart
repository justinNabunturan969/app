library;

import 'dart:js_interop';

/// Web-only bridge for [SessionLifecycleGuard].
///
/// This file is imported only when `dart.library.js_interop` is available
/// (i.e. the web target). It uses `dart:js_interop` to listen for browser
/// `visibilitychange` events so a returning student is re-marked online
/// immediately. On native targets the conditional-import stub
/// (`session_lifecycle_guard_stub.dart`) supplies no-op equivalents.

// ── JS bridge ────────────────────────────────────────────────────────
// `window`, `document`, and `addEventListener` only exist on the web
// target, so all of this lives in a web-only file.

@JS('window.addEventListener')
external void _windowAddEventListener(JSAny type, JSAny listener);

@JS('window.removeEventListener')
external void _windowRemoveEventListener(JSAny type, JSAny listener);

@JS('document.visibilityState')
external String? _documentVisibilityState();

/// Returns the current browser document visibility state
/// (`'visible'`, `'hidden'`, or `'prerender'`).
String? documentVisibilityState() => _documentVisibilityState();

/// Registers a `visibilitychange` listener and returns an opaque handle
/// that can be passed to [unregisterVisibilityChange].
Object registerVisibilityChange(void Function() onVisible) {
  final fn = ((JSObject _) {
    if (documentVisibilityState() == 'visible') onVisible();
  }).toJS;
  _windowAddEventListener('visibilitychange'.toJS, fn);
  return fn;
}

/// Removes a listener previously registered with
/// [registerVisibilityChange].
void unregisterVisibilityChange(Object handle) {
  _windowRemoveEventListener('visibilitychange'.toJS, handle as JSFunction);
}

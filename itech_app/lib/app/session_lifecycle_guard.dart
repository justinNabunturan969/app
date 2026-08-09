import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/repositories/user_repository.dart';

/// Keeps the current user's `active_sessions` row in sync with the
/// app's actual lifecycle.
///
/// - **Native (iOS / Android / desktop):** `AppLifecycleListener` fires
///   `onPause` when the app moves to the background, `onDetach` when
///   it's about to be torn down, and `onHide` when it's no longer
///   visible. Any of those means the user is no longer "live", so
///   we drop the row. `onResume` / `onShow` re-register the row so
///   the user comes back online when they return.
///
/// - **Web:** `AppLifecycleState.hidden` covers tab switches, but
///   the only reliable signal for "tab is being closed" is the
///   browser's `pagehide` event. We register a JS listener via
///   `dart:js_interop` that fires the same cleanup. Note: the
///   browser will not wait for the async Supabase delete to
///   complete, so this is best-effort — a stale row is acceptable
///   because the user is no longer interacting with the app.
class SessionLifecycleGuard extends StatefulWidget {
  const SessionLifecycleGuard({
    super.key,
    required this.userRepository,
    required this.child,
  });

  final UserRepository userRepository;
  final Widget child;

  @override
  State<SessionLifecycleGuard> createState() => _SessionLifecycleGuardState();
}

class _SessionLifecycleGuardState extends State<SessionLifecycleGuard> {
  AppLifecycleListener? _listener;
  JSFunction? _webCleanupFn;

  @override
  void initState() {
    super.initState();

    // Native lifecycle hooks. `onPause` / `onHide` mean the user
    // can no longer see the app, so we drop the session row. We
    // also handle `onDetach` for desktop platforms where the app
    // can be torn down without going through `paused` first.
    _listener = AppLifecycleListener(
      onPause: _markOffline,
      onHide: _markOffline,
      onDetach: _markOffline,
      onResume: _markOnline,
      onShow: _markOnline,
    );

    if (kIsWeb) {
      _webCleanupFn = _registerPageHide((_) {
        // Fire and forget — the page is unloading and we cannot
        // block on the Supabase round-trip.
        unawaited(_markOffline());
      });
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    if (kIsWeb && _webCleanupFn != null) {
      _unregisterPageHide(_webCleanupFn!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _markOffline() async {
    try {
      await widget.userRepository.removeOwnSession();
    } catch (_) {
      // Best effort. A stale row is acceptable here.
    }
  }

  Future<void> _markOnline() async {
    try {
      await widget.userRepository.markOwnSessionActive();
    } catch (_) {
      // Best effort.
    }
  }
}

// ── Web bridge ────────────────────────────────────────────────────────
// dart:js_interop is available on every platform, but `window` and
// `addEventListener` only exist on the web target. We guard the call
// site with `kIsWeb` (above) and the externs themselves are wrapped in
// a JS-accessible shape so the call is type-safe from Dart.

@JS('window.addEventListener')
external void _windowAddEventListener(JSAny type, JSAny listener);

@JS('window.removeEventListener')
external void _windowRemoveEventListener(JSAny type, JSAny listener);

JSFunction _registerPageHide(void Function(JSObject event) handler) {
  final fn = ((JSObject e) => handler(e)).toJS;
  _windowAddEventListener('pagehide'.toJS, fn);
  return fn;
}

void _unregisterPageHide(JSFunction fn) {
  _windowRemoveEventListener('pagehide'.toJS, fn);
}
